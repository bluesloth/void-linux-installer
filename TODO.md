# TODO / Open Items

## >>> RESOLVED — COSMIC grey-screen root cause + fix (2026-09-06, Beta-v2.9.12) <<<
- **ROOT CAUSE (closed):** cosmic-greeter's `src/main.rs` dispatches on the
  **current username**: only `"cosmic-greeter" => greeter::main()` (the greetd
  DM that draws the user list / login panel); anything else falls through to
  `locker::main()` (no main window; waits for an ext-session-lock event; maps
  nothing). The REDACTED/void-packages template ships
  `system_accounts="_cosmicgreeter"`, and the Beta-v2.9.10 recipe copied it, so
  greetd ran the binary under a non-matching user and the greeter silently took
  the locker branch → grey wallpaper + cursor, no login UI.
- **Evidence (live, `Debug/Cosmic-Greeter/triage10-wayland-debug.md`):** with
  `WAYLAND_DEBUG=1`, the greeter client bound `xdg_wm_base`/
  `zwlr_layer_shell_v1`/`ext_session_lock_manager_v1` and created exactly ONE
  `wl_surface` that never got a role (no `get_xdg_surface`/`get_layer_surface`/
  `get_lock`/attach/commit). Session log carried the `cosmic_greeter::locker`
  tracing target and the process never connected to its `GREETD_SOCK`. The
  earlier `cosmic_greeter::common: []` line was the KEYBOARD layouts log
  (`active_layouts`), not an empty user list — AccountsService + daemon
  `GetUserData` were fine all along.
- **FIX (verified live — login panel appeared on tty1):** rename the account to
  exactly `cosmic-greeter` (`usermod -l cosmic-greeter _cosmicgreeter` +
  group rename + `usermod -aG video,input`), then `sv up` both services. Log
  target switched `locker` → `greeter`, greeter connected to the greetd socket.
- **Installer now ships the fix** (Beta-v2.9.12 `[COSMIC-GREETER-USER]`):
  provision `cosmic-greeter`, toml `user = "cosmic-greeter"`, daemon run
  `-o cosmic-greeter -g cosmic-greeter`. Do NOT reintroduce `_cosmicgreeter`.
- Machine context (kept for forensics): `<host>` AMD HawkPoint/amdgpu, eDP-1
  1920x1200; box scripts `/var/log/cosmic-greeter-session.log`,
  `~/fix-cosmic-greeter.sh`. No Vulkan loader/radv on box (LLVMPIPE fallback) —
  secondary, not causal.
- Session logs + worker scripts live in `Debug/Cosmic-Greeter/` here.

## MATE + Slick greeter still black (real Beta-v2.9.8 MATE install)
- Slick greeter shows a black login screen despite the Beta-v2.9.8
  `[GREETER-BG-TIMING]` fix (block moved after the desktop install,
  gnome-backgrounds retry).
- Working hypotheses, ranked: (1) the search fell back to a dark
  `mate-backgrounds` wall (MATE ships no adwaita-l, so it takes filesystem-
  first match); (2) `/etc/lightdm/slick-greeter.conf` was never written; (3)
  Slick cannot decode the pointed image. Verify on the target via the v2.9.9
  terminal: `cat /etc/lightdm/slick-greeter.conf`, `ls /usr/share/backgrounds/mate/`,
  `grep greeter-session /etc/lightdm/lightdm.conf`, `sv status accounts-daemon`,
  `tail /var/log/lightdm/lightdm.log`.
- Only patch code if conf + image + lightdm state are confirmed correct but the
  greeter still renders black.

## Limine bootloader background not showing
- User does not see the boot-screen wallpaper on the real install. Before
  touching code: check the target's `/etc/void-installer/limine-env`
  (`LIMINE_WALLPAPER`, `LIMINE_WALLPAPER_STYLE`) and whether the image file
  actually landed on the ESP (`/boot/efi/limine-splash.<ext>`). The guarded
  design (invariant #9, `[LIMINE-WALLPAPER]`) only emits `wallpaper:` when the
  ESP file exists — a missing image is the most likely cause. Verify on the
  target medium first; only patch code if limine-env + ESP file are confirmed
  present but limine.conf still lacks the directive.

## COSMIC + cosmic-greeter DM: greetd path RUNS but renders grey (validated 2026-09-05)
- **RESOLVED 2026-09-06** by Beta-v2.9.12 `[COSMIC-GREETER-USER]` (see top of
  this file): the account must be exactly `cosmic-greeter`, not
  `_cosmicgreeter`; the binary dispatches greeter-DM vs silent-locker off the
  current username. Live-fixed on the box; installer updated.
- DONE — Beta-v2.9.11 `[COSMIC-GREETER-LOG]`: `/etc/sv/cosmic-greeter/log` and
  `/etc/sv/cosmic-greeter-daemon/log` were created with NO `run` script, so
  runsv spammed `fatal: unable to start log/./run: file does not exist` and no
  svlogd logging survived a reboot. The installer now writes a standard Void
  svlogd `log/run` (`exec svlogd -tt /var/log/<svc>`, root-owned 0750 log dir)
  under BOTH services. (The box-side `~/fix-cosmic-greeter.sh` was superseded
  by the live `usermod` fix and then by the installer's corrected provisioning.)
- DONE — live diagnosis on the box (2026-09-06, greeter was/alive grey):
  * accounts-daemon is supervised and `org.freedesktop.Accounts.ListCachedUsers`
    returns `User1000` — the accounts UI-population hypothesis is REFUTED; the
    greeter can enumerate users. (This was correct but NOT the cause — see the
    username-dispatch root cause at the top of this file.)
  * cosmic-comp composites via Mesa LLVMPIPE (no Vulkan loader/radv on this
    box) — secondary avenue (install `vulkan-loader mesa-vulkan-radeon`) was
    never needed once the account rename fixed the real cause.
- NEXT (retain as post-fix verification): confirm a login from the now-visible
  COSMIC greeter actually starts the `[COSMIC-GREETER-DM]` session and the
  `[COSMIC-POLKIT]` agent dialog appears.
- **POST-FIX VERIFICATION (resolved, 2026-09-06, Beta-v2.9.13):** login works —
  full COSMIC session starts (greetd session-worker → `dbus-run-session
  cosmic-session`), greeter account/services/logs all healthy. BUT the polkit
  agent was a `<defunct>` zombie: cosmic-session autostarted it before
  cosmic-comp/session-bus was up and it died once (verified by test-running
  the binary with the live session env — it runs clean indefinitely; the
  timing is the fault). Beta-v2.9.13 `[COSMIC-POLKIT-GUARD]` now launches the
  agent via `/usr/local/sbin/cosmic-polkit-guard` which waits for the
  compositor socket + reachable session bus and respawns on exit.
  Beta-v2.9.13 `[ACCTSVCS-ICON]` clears the other log noise: a real default
  avatar (Adwaita/Pop `avatar-default`) is now provisioned at
  `/var/lib/AccountsService/icons/<user>` right after useradd. Residual,
  unfixable from the installer (documented): the daemon's
  `config.ron ExpectedComma` error parses the binary's EMBEDDED default — no
  `config.ron` exists anywhere (greeter home, /root, user config) to provision.
- **APPLIED LIVE on `<host>` (2026-09-06 ~17:10 EDT, Beta-v2.9.13):**
  `/usr/local/sbin/cosmic-polkit-guard` written (agent baked in), autostart
  .desktop repointed at it, and
  `cp /usr/share/icons/Adwaita/scalable/status/avatar-default.svg /var/lib/AccountsService/icons/<user>`.
  Verified: `sv restart cosmic-greeter-daemon` → the per-boot
  `failed to open icon <user>` ERROR is **gone** (residual log now only the
  WARN journald line); a session-context guard launch produced a **live**
  `/usr/libexec/polkit-gnome-authentication-agent-1` (STAT Sl, not zombie)
  connected to both the session bus and polkitd. The old `<defunct>` 2206
  remains until logout (cosmic-session never reaps it — harmless). Next
  reboot/login will exercise the guard through the autostart path;
  confirm a real polkit dialog then (the earlier `timeout 4` test-run
  already proved the binary runs clean indefinitely given session env, so
  the guard's only job is correct timing/respawn).