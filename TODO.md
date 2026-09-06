# TODO / Open Items

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
- Next debugging step: re-provision the logger runs on the box, capture
  `cosmic-greeter`/`cosmic-comp` output, and determine whether the missing
  element is accountsservice UI population (accounts-daemon is linked) or the
  greeter theme/wallpaper only. Per the old grub branch of this story, test
  logging in blind is not possible (no UI); instead capture
  `cosmic-greeter`/`cosmic-comp` output. Confirm logins start a session and
  the `[COSMIC-POLKIT]` agent dialog appears.