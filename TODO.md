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