# TODO / Open Items

## OPEN — cosmic-greeter 1.10 DM: runtime elogind-session verification
- **Authoritative entry lives in `AGENTS.md` → "Validation backlog"**
  (kept there so this TODO does not diverge from the work-state doc).
  Short form: the COSMIC 1.10 `cosmic-greeter` DM is packaged +
  signature-verified (2026-10-10) but its elogind session recognition is
  UNPROVEN on a real boot. Verify on the next install with DM=cosmic-greeter;
  fall back to SDDM on a grey bounce.

## OPEN — DISCUSSION: installer version-control topology (three repos, zero remotes)
- Verified 2026-10-10: three installer repos exist on this USB, **none with a
  remote** (`git remote -v` is empty on all three):
  (a) the root workspace repo — `main` — session docs only (AGENTS.md,
      HANDOFF-*, opencode.json, per `.gitignore` `/*`; HEAD `b4cf08e`);
  (b) `repo/` — `history-split-doc` — the actual project (script, CHANGELOG,
      TODO, README, Debug), clean at HEAD `0d3215d`;
  (c) `Void_Linux_LineageAnchor_v2.9.13/` — `main` — anchor-era snapshot whose
      **committed `Void_Linux_Installer.sh` is 424 deletions / 5610 insertions
      behind its own working tree** (the 2026-10-10 swap to the newest build;
      documented in SWAP-NOTE + `.bak`, not committed).
- Discussion points:
  1. **Single point of failure.** Every commit lives only on this removable
     USB (b1ade0f … 0d3215d, b4cf08e, 44ffdb3). Same risk class as the Cosmic
     signing-key warning. Option: give `repo/` (or the root repo) an `origin`
     — mirror how void-cosmic-repo is published.
  2. **No canonical repo.** Three scopes, three branch names
     (`main`/`history-split-doc`/`main`). Before ever publishing the installer
     to GitHub, pick one source of truth; the `history-split-doc` name implies
     a planned history split that was never materialised.
  3. **LineageAnchor's uncommitted swap.** Commit the swap (keeping `.bak`
     untracked as the baseline record), or keep old HEAD + SWAP-NOTE as the
     only record? Do NOT `git add -A && git commit` there blindly.
  4. **Root-repo guardrail.** `.gitignore` `/*` keeps `repo/` + LineageAnchor
     out of the root repo; if that ignore is ever removed, a root `git add -A`
     would ingest the nested repos as gitlinks — be deliberate.
- Status: user declined action for now (2026-10-10) — retained as a discussion
  point for a future session. Cross-ref: AGENTS.md → Next Move (d).

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

## MATE + Slick greeter still black (real Beta-v2.9.8 MATE install) — RESOLVED
- RESOLVED in the pre-reconstruction script; the fix is carried in the
  reconstructed tree. Beta-v2.9.8 `[GREETER-BG-TIMING]` (greeter-bg block moved
  AFTER the desktop install with the gnome-backgrounds retry) plus Beta-v2.9.34
  `[SLICK-BG-QUOTES]` (slick-greeter background written UNQUOTED — slick does
  not strip quotes, so a quoted path rendered the literal `"/path"` → black
  greeter) remove the failure modes seen on this MATE install. The live `<host>`
  box (DESKTOP_ENV=mate) boots to a working greeter.
- The on-target triage list (slick-greeter.conf, backgrounds listing,
  lightdm.conf greeter-session, accounts-daemon status, lightdm.log tail)
  stays the standard first pass should a fresh MATE+slick report ever appear.

## Limine bootloader background not showing — RESOLVED
- RESOLVED in the pre-reconstruction script; the fix is carried in the
  reconstructed tree. The guarded design (invariant #9, `[LIMINE-WALLPAPER]`)
  plus the Beta-v2.5.4 `[LIMINE-WALLPAPER-BROWSE]` /
  `[LIMINE-WALLPAPER-OPT-OUT]` and the Beta-v2.9.18 `[LIMINE-WALLPAPER-STAGE2]`
  stage2 fix (splash image staged on the ESP so it survives the mount/swap;
  `void-limine-write-conf` emits `wallpaper:` only when the ESP file exists)
  cover the reported missing-background failure. The live `<host>` box
  (BOOTLOADER=limine) boots fine.
- The verify-first checklist (limine-env flags + `/boot/efi/limine-splash.<ext>`
  existence) remains the standard triage before any code change should a fresh
  missing-wallpaper report appear.

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

## cosmic-store pulls flatpak if installed — RESOLVED as INSTALL_COSMIC_STORE (Beta-v2.9.84)
- `cosmic-store` (1.9.0, bluesloth repo) runtime-depends on `flatpak` —
  verified with `xbps-query -R cosmic-store` (`run_depends: flatpak`) — so
  **installing cosmic-store** auto-installs the flatpak package even when the
  prompt `INSTALL_FLATPAK` was declined (the Stage-2 flatpak gate — the
  `if [ "$INSTALL_FLATPAK" = "true" ]; then install_pkgs flatpak fuse fuse3`
  block in the package-install section — is gated on the prompt, but xbps
  auto-resolves the store's dependency regardless). No file/pkg conflict —
  same Void repo package, nothing pinned — purely a scope/behavior surprise
  for opt-outs.
- **SOLVED 2026-10-07 (Beta-v2.9.84, `[COSMIC-STORE]` + `[FLATPAK-PULL-DETECT]`):**
  - New opt-in prompt `INSTALL_COSMIC_STORE` (default NO), offered ONLY when
    `INSTALL_FLATPAK=true` (any desktop — the store is a Flathub GUI, not
    cosmic-only); Stage-2 install re-checks `INSTALL_FLATPAK` and WARNs + skips
    if a stale resume state carried store=yes && flatpak=no — mirroring the
    Brave gate exactly, never a silent flatpak pull.
  - Installed in-chroot as a second package in the same `install_cosmic()`
    call as `cosmic-desktop-full` (same bluesloth repo, same pinned-key path).
  - `[FLATPAK-PULL-DETECT]` Stage-2 safety net covers the toggle's blind
    spots (a future `cosmic-desktop-full` revision or a manual
    `xbps-install`): declined flatpak that still lands installed triggers a
    loud WARNING + `FLATPAK_PULLED_BY="<reverse deps>"` row in install-config.
  - Threaded through resume-state, chroot_env, dry-run plan, install-config.
- NOTE: `cosmic-store` is deliberately **NOT in `cosmic-desktop-full`'s
  depends** (`_7`, 47 deps — re-verified: 0 matches) — unchanged conclusion.
- Line references deliberately omitted (they rot on every version bump — an
  earlier draft said "line 8415", already wrong by 2.9.83); find the gate by
  the `install_pkgs flatpak fuse fuse3` literal instead.
