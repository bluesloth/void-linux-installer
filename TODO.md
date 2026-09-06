# TODO / Open Items

## >>> PICKUP HERE — COSMIC grey-screen, reboot in progress (2026-09-06 ~09:00 EDT) <<<
- Machine is `<host>` (AMD HawkPoint/amdgpu, eDP-1 1920x1200). Repo is on the
  USB this machine hosts; scripts + logs live on the box's own disk and
  SURVIVE reboot: `~/fix-cosmic-greeter.sh`, `~/cosmic-greeter-diagnose.sh`,
  `/var/log/cosmic-greeter-session.log`, `/var/log/cosmic-greeter-triage.txt`,
  `/var/log/cosmic-greeter-diagnose.txt`, `/var/log/cosmic-greeter{,-daemon}/current`.
- BOUNDARY DECISION MADE IMMEDIATELY BEFORE REBOOT: the `config.ron` /
  `ExpectedComma line 4` lead is DEAD — no `/root/.config/cosmic-comp` exists,
  no `config.ron` exists anywhere (only `/var/lib/cosmic-greeter/.local/state/
  cosmic-comp/outputs.ron` and pop-launcher's) — that error comes from bundled
  in-binary defaults, not disk. Vulkan is fully absent: no `libvulkan.so.1`,
  only `libvulkan_virtio.so` + virtio ICDs; the radv driver lives in the SEPARATE
  Void package `mesa-vulkan-radeon`, which is NOT installed (`mesa` metapackage
  doesn't pull it). The 12:30:13 `Failed to commit on clear_state ... /dev/dri/
  card0 (Permission denied)` in the session log is an ARTIFACT of the
  in-place-restart debugging (user session 2 held the seat/DRM master on tty2);
  a fresh boot leaves `_cosmicgreeter` as the sole seat session, which is the
  ONLY reproducible reproduction of the grey screen.
- THE PLAN RIGHT AFTER THIS REBOOT:
  1. Let it boot to the grey screen on tty1 (do NOT log into tty2 first).
  2. Run `sudo bash ~/cosmic-greeter-diagnose.sh` (note: it overwrites
     `/var/log/cosmic-greeter-diagnose.txt`), then read that txt — the boot-time
     `cosmic-greeter-session.log` capture is the key artifact.
  3. If boot-time errors are missing/clean, apply the Vulkan avenue:
     `sudo xbps-install -Sy vulkan-loader mesa-vulkan-radeon` then
     `sudo sv restart cosmic-greeter` (or reboot).
  The re-runnable `Debug/Cosmic-Greeter/fix-cosmic-greeter.sh` and
  `cosmic-greeter-diagnose.sh` are now saved in THIS repo (not just on the box).
- Session logs live in `Debug/Cosmic-Greeter/` here (diagnose + triage + session
  log snapshots synced at 08:57). Worker scripts: `Debug/Cosmic-Greeter/
  fix-cosmic-greeter.sh`, `cosmic-greeter-diagnose.sh`.

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
- Live validity run of the Beta-v2.9.10 `[COSMIC-GREETER-DM]` recipe via
  `~/fix-cosmic-greeter.sh` on a real Beta-v2.9.9 COSMIC box. Result: the
  greetd-hosted path LAUNCHES cleanly — greetd session-worker 11,
  `cosmic-comp cosmic-greeter`, Xwayland :0 and the `cosmic-greeter` app are
  all alive as `_cosmicgreeter` on VT 1 — but tty1 shows only a grey
  wallpaper + mouse cursor, NO login UI. Greeter app runs but doesn't draw its
  user list / login panel. STILL OPEN (render bug).
- DONE — Beta-v2.9.11 `[COSMIC-GREETER-LOG]`: `/etc/sv/cosmic-greeter/log` and
  `/etc/sv/cosmic-greeter-daemon/log` were created with NO `run` script, so
  runsv spammed `fatal: unable to start log/./run: file does not exist` and no
  svlogd logging survived a reboot. The installer now writes a standard Void
  svlogd `log/run` (`exec svlogd -tt /var/log/<svc>`, root-owned 0750 log dir)
  under BOTH services. The box-side `~/fix-cosmic-greeter.sh` still needs the
  same two `log/run` bodies (copy them from the installer's cosmic-greeter
  branch) or its greeter/compositor output will remain uncaptured.
- DONE — live diagnosis on the box (2026-09-06, greeter was/alive grey):
  * accounts-daemon is supervised and `org.freedesktop.Accounts.ListCachedUsers`
    returns `User1000` — the accounts UI-population hypothesis is REFUTED; the
    greeter can enumerate users.
  * The grey is cosmic-comp itself: it composites (grey background + cursor)
    via Mesa LLVMPIPE software fallback — there is NO Vulkan loader
    (`libvulkan.so.1` absent) and NO AMD Vulkan ICD (only the virtio stub ICD
    is installed) on this HawkPoint/amdgpu box. So compositing works, but the
    greeter app's OWN login panel (an iced/wgpu client; the binary also embeds
    `iced_tiny_skia`) never maps as a Wayland layer. The greeter app process is
    alive, owns `com.system76.CosmicGreeter` on the system bus, and is a
    connected Wayland client — so its environment is fine and its render/UI
    startup is failing silently (stderr was previously dropped by the
    bare `log/` dirs; the daemon's `log/` had no run at all).
  * Secondary avenue: install `vulkan-loader mesa-vulkan-radeon` (radeonsi
    ICD) and retest; cosmic-comp prefers a real Vulkan device to LLVMPIPE.
    Not strictly required (LLVMPIPE ran), but worth ruling out.
- NEXT: run the updated `~/fix-cosmic-greeter.sh` (now writes both svlogd
  `log/run` bodies and restarts both services) and read
  `/var/log/cosmic-greeter/current` + `/var/log/cosmic-greeter-daemon/current`
  ~10s after the restart for the iced/wgpu surface/adapter errors. Determine
  why the iced login panel fails to surface as a layer; only then decide
  whether a restart-only workaround (relaunch greeter after cosmic-comp is up,
  add a session bus, grant the greeter VT) or an installer code change is
  warranted. Confirm logins start a session and the `[COSMIC-POLKIT]` agent
  dialog appears.