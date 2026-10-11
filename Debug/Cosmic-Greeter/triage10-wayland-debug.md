# triage10 — WAYLAND_DEBUG protocol capture (2026-09-06 20:20Z)

## Result: GREETER IS A CLIENT-SIDE STALL, NOT A PROTOCOL GAP

Compositor `cosmic-comp` advertises every global the greeter needs:

- `xdg_wm_base` v7
- `zwlr_layer_shell_v1` v5
- `ext_session_lock_manager_v1` v1
- `zcosmic_toplevel_manager_v1` v4
- seat, output, shm, dmabuf, etc.

The greeter client (the iced login window) then:

1. binds globals (incl. `ext_session_lock_manager_v1` as id 47)
2. creates **exactly one** `wl_surface#63` (20:20:23.212434)
3. gets keyboard `#61`, text-input `#62`, pointer `#64`, touch `#67`
4. **then stops producing ANY wayland requests**

Missing entirely from `->` traffic:
- NO `xdg_wm_base.get_xdg_surface`
- NO `zwlr_layer_shell.get_layer_surface`
- NO `ext_session_lock_manager_v1.get_lock` / `ext_session_lock.*.lock`
- NO `wl_surface.attach`, NO `wl_surface.commit`
- NO dmabuf/shm buffer creation

The compositor also sends no `locked` event — but that is expected, because the
client never sent `get_lock`.

## Meaning

- The grey screen + cursor is cosmic-comp's own scanout (wallpaper paths were
  already proven working; DRM-master WARN is benign).
- The iced login panel surface is created at the Wayland protocol level but is
  **never given a role and never committed** — i.e. the greeter's `iced_winit`
  event loop created the raw surface but never reached the app-window mapping
  step.
- This is consistent with `cosmic_greeter::common: []` (empty user list at
  init) + `iced_winit: System theme: None` + then silence: the iced app is
  waiting for something (user data / session / greeter init) before it maps.

## Where in the stall the app is stuck (binary-string evidence)

- Binary contains `Opening GREETD_SOCK`, `GREETD_SOCK variable not set` —
  greeter talks to greetd, and `GREETD_SOCK` is set in its env at runtime.
- `XDG_SESSION_ID=15`, `XDG_SESSION_TYPE=tty`, `XDG_VTNR=1`.
- Session bus (dbus-run-session) IS present and reachable (webauth observed
  dbus-daemon), so the v5 assumption is not wrong — it is just insufficient.

## Env captured (greeter pid 23911)
```
DISPLAY=:0
WAYLAND_DISPLAY=wayland-1
XDG_RUNTIME_DIR=/run/user/988
DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/dbus-...
GREETD_SOCK=/run/greetd-23801.sock
XDG_SESSION_ID=15
XDG_SESSION_TYPE=tty
XDG_VTNR=1
HOME=/var/lib/cosmic-greeter
SHELL=/sbin/nologin
```

## Config state (already inspected, all "clean")
- `.config/cosmic/*/v1/` dirs under `/var/lib/cosmic-greeter` empty.
- `outputs.ron` well-formed.
- `/var/lib/AccountsService/users/` empty (daemon GetUserData still returns
  <user>+cosmic theme — so user discovery itself works from /etc/passwd).

## Proven working meanwhile
- Vulkan installed (vulkan-loader + mesa-vulkan-radeon) before every capture.
- DRM master WARN benign (atomic scans proven by wallpaper+cursor).
- Daemon `GetUserData` returns full <user> + cosmic theme (called as root AND
  as uid 988 on the system bus).

## Packages
- cosmic-comp 1.2.0_1, cosmic-greeter 1.2.0_1, greetd 0.10.3_2.

## Next candidates (in order of suspicion)
1. iced app never receives the "greeter is ready → map the login window"
   signal because the daemon's user-list delivery (`cosmic_greeter::common`)
   or the greetd socket conversation stalls.
2. `XDG_SESSION_TYPE=tty` (greetd sets it) vs wayland — cosmic-iced window
   mapping may key off session type/env it expects from a "real" session
   manager.
3. Missing `XDG_CURRENT_DESKTOP`/`COSMIC_*` env the iced stack consults at
   window-creation time.

---

## RESOLVED SAME DAY — the stall WAS the account name (Beta-v2.9.12)

The "result" above is byte-for-byte correct but its *interpretation* was the
trap: this is exactly what the **locker** branch of cosmic-greeter produces,
not a "stalled greeter". `src/main.rs` dispatches on the current username:

```rust
match u.name.as_str() {
    "cosmic-greeter" => greeter::main(),   // DM: user list, layer surfaces, greetd IPC
    _                => locker::main(u),   // no_main_window: waits for ext-session-lock, maps nothing
}
```

`_cosmicgreeter` (the community repo's `system_accounts` value, which
Beta-v2.9.10 had copied) falls into the wildcard → **locker branch**. The
single uncommitted `wl_surface`, the never-created role, the idle client, the
`cosmic_greeter::locker` journald target, and the never-connected `GREETD_SOCK`
are all the locker's fingerprint. `env` from pid 23911 even shows
`HOME=/var/lib/cosmic-greeter` but the whole process was running as uid 988
(`_cosmicgreeter`) — that username mismatch IS the bug.

**Live fix (login panel appeared on tty1):**
```
usermod -l cosmic-greeter _cosmicgreeter -d /var/lib/cosmic-greeter
groupmod -n cosmic-greeter _cosmicgreeter    # group was renamed first
usermod -aG video,input cosmic-greeter
sv up cosmic-greeter-daemon cosmic-greeter   # after both were sv down
```
Session log switched `cosmic_greeter::locker` → `cosmic_greeter::greeter`;
greeter connected to `/run/greetd-<pid>.sock` (ESTAB); login panel rendered.
Installer now provisions `cosmic-greeter` (Beta-v2.9.12 `[COSMIC-GREETER-USER]`).