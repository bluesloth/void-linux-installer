# REVIEW.md — boot/validation review list

Human-driven review queue for real-hardware findings that need a root-cause
determination before being closed. Each entry records the report, the facts
known from the installer source, the candidate hypotheses in rank order, and
how to prove/retest. Entries here are INVESTIGATIONS, not promises — a fix is
only merged after a hypothesis is proven on the target medium and the entry
is marked `RESOLVED` with the verdict.

Gates: `bash -n Void_Linux_Installer.sh`, `./Debug/check-heredocs.sh`
(40 heredocs, ALL CLEAN), shellcheck triage when available. Run on the target
medium, never the dev box. The `Debug/yk_validation/PROTOCOL.md` protocol is
the sibling for YubiKey possession-only boot; this file covers everything else.

---

## Entry #1 — ENCRYPT boot unlock rejects the correct install-time passphrase (RESOLVED)

**Reported:** Beta-v2.6.2 install, `ENCRYPT=yes`, YubiKey **declined**
(`YK_MODE=off`), `BOOTLOADER=limine`. First boot prints the stock dracut
prompt `Enter passphrase for /dev/nvme0n1p2:` and, on the SAME passphrase
that was typed twice during installation, returns:
`No key available with this passphrase.`

**Facts from the installer source:**
- Passphrase capture is `read -r -s` + double-entry match
  (Void_Linux_Installer.sh ~1139-1170).
- Fresh install: `cryptsetup luksFormat --type luks2 -q --key-file=- "$PART_SYS" <<<"$ENCRYPT_PASSPHRASE"`
  then `luksOpen --key-file=- "$PART_SYS" void-root <<<"$ENCRYPT_PASSPHRASE"`
  (~2546-2548). The install-time `luksOpen` decides the whole install, so at
  the moment of format the captured passphrase DID open the keyslot,
  otherwise the install aborts there. YubiKey branch (`luksAddKey` /
  `luksRemoveKey`) is gated on `YK_MODE=hmac-sha1` and is NOT on this box, so
  the keyslot holds exactly what `luksFormat` was fed.
- `YK_MODE=off` also means the `99void-yubikey` dracut module is not built —
  boot unlock is the STOCK dracut `crypt` module reading crypttab
  `void-root UUID=$LUKS_UUID none luks`. The prompt text observed (plain
  device path, no keyscript) is consistent with the stock module, so no
  custom keyscript is implicated.
- limine-env persists `rd.luks.uuid=$LUKS_UUID rd.luks.name=...=void-root`
  ONLY when `ENCRYPT=yes`; the boot prompt naming `/dev/nvme0n1p2` shows the
  UUID matched the actual LUKS header, ruling out a wrong-container prompt.

**Hypotheses (rank order):**

1. **Initramfs keymap mismatch (most likely).** The dracut initramfs for this
   build carries the `crypt` module but no `keymap`/`console-setup` module
   (nothing adds `i18n`/keymap to `add_dracutmodules`, so the early-boot vt
   console defaults to the kernel US layout). If the install-time terminal
   (live USB) used a NON-`us` layout, every passphrase character typed under
   a shifted/special key — or anything non-ASCII — is written to the keyslot
   as one byte string and re-typed at boot under the `us` layout as a
   DIFFERENT byte string, so the keyslot lookup fails exactly like this.
   ASCII-only QWERTY passphrases are unaffected. **Proof:** reinstall (or
   re-open the volume from the live medium) with a passphrase made ONLY of
   `us`-layout-safe ASCII characters `[A-Za-z0-9]`: if boot unlock succeeds,
   the passphrase itself was fine and H1 is confirmed. Fix direction if so:
   add keymap to the initramfs (`add_dracutmodules+=" i18n"`, bake the chosen
   `KEYMAP`/vconsole into dracut.conf, ship the same layout the prompts
   typed under).

2. **bash `read` trailing-whitespace stripping.** `read -r -s` with default
   `IFS` applies field splitting to the capture, dropping leading/trailing
   IFS whitespace from `ENCRYPT_PASSPHRASE` (both entries equally, so the
   double-entry match passes). A passphrase ending in a space is stored in
   the keyslot WITHOUT it; at boot the typed line is taken literally, so the
   typed passphrase with its trailing space misses the slot. Edge case, but a
   one-line hardening: capture with `IFS= read -r -s`. **Proof:** reproduce
   with a passphrase ending in a space; if boot rejects it while the
   space-less variant opens, H2 is confirmed.

3. **User-entry drift (least likely, must still be excluded).** A different
   passphrase was actually stored (typo not caught by double-entry — e.g.
   both bounding types agreed with each other but a layout shift happened
   between the two live-session frames). Excluded by H1's proof, which
   isolates the byte string at keyslot-write time.

**Verdict — RESOLVED (2026-09-14, live-system evidence).** The reported symptom
was fixed in the pre-reconstruction script by Beta-v2.6.9 `[ENCRYPT-KEYMAP]` +
`[ENCRYPT-VERIFY]`; H1 (initramfs keymap mismatch) is confirmed as the root
cause. The initramfs historically shipped NO `i18n` module, so early-boot
`cryptroot-ask` used the kernel US layout regardless of the install-time
console, and any passphrase byte sequence typed on a non-US/special-key layout
was written to the keyslot differently than it was re-typed at boot.

**Fix (carried in the reconstructed script):**
- Capture `KEYMAP_LIVE` from the live medium's `/etc/rc.conf` and pin the
  installed `/etc/rc.conf` `KEYMAP=` to it on the chroot side
  (~6537-6546), so the runit console matches the live console.
- Append `add_dracutmodules+=" i18n "` and `rd.vconsole.keymap=${KEYMAP_LIVE}`
  to `/etc/dracut.conf.d/90-system.conf` (~10574-10580), so the early-boot
  passphrase prompt runs under the SAME keymap the passphrase was typed under.
- `[ENCRYPT-VERIFY]` (~5188-5211): right after format+open, close and re-open
  with the byte-identical passphrase (`printf '%s'`, no trailing newline) and
  abort with an actionable FATAL if the keyslot does not round-trip — a
  welded-shut disk can never reach boot, so it is caught at install time.

**Live proof:** `<host>` (as-built record, vBeta-v2.9.43, ENCRYPT=yes) boots its
LUKS2 volume normally, and `/etc/dracut.conf.d/90-system.conf` carries exactly
`add_dracutmodules+=" i18n "` + `rd.vconsole.keymap=us` — the on-disk state the
reconstruction reproduces (verified on the live machine 2026-09-14).

H2 (`read` trailing-whitespace stripping) was NOT the cause on this system and
stays an unproven, optional one-line hardening (`IFS= read -r -s` at the
~2588/~2595 capture) to apply only if a future report describes a passphrase
that fails only because it trails in a space.

**Chronology note (user correction, 2026-09-14):** the pre-ext4 era enjoyed
working decrypt — the 2.6.9 keymap/verify fix above was that era's unlock fix.
The ext4 introduction (Beta-v2.9.38 `[MULTI-FS]`: carved regions relocated into
an INNER GPT inside the LUKS container) then RE-broke boot decryption, and the
fix — one or more attempts — landed AFTER ext4 across 2.9.43/2.9.44/2.9.45
(`[INNER-PARTSCAN-BOOT]`, `[DRACUT-CONF-NAME]`, `[INNER-PARTSCAN-DMPROBE]`)
plus the 2.9.46 post-audit batch. The live `<host>` (as-built record installed by
vBeta-v2.9.43, ENCRYPT=yes, `DATA_REGIONS` home:ext4 + games:ext4) boots its
LUKS2 container today — the on-hardware proof of the post-ext4 decryption fix.

---

## Entry #2 — WebKit2 greeter renders a black screen with blinking cursor (RESOLVED: removed the option)

**Reported:** Beta-v2.9.0 install, `BOOTLOADER=limine`, `ENCRYPT=yes`,
`DESKTOP_ENV=cinnamon`, `DISPLAY_MANAGER=lightdm`. With `LIGHTDM_GREETER=gtk`
and `slick` the machine boots to the desktop; with `LIGHTDM_GREETER=webkit2`
(lightdm-webkit2-greeter) the screen **flashes then goes black with a
blinking cursor** at the greeter stage. Vendor: **AMD**.

**Facts from investigation:**
- `lightdm-webkit2-greeter` is an **abandoned upstream project** — the
  source repo (`Antergos/web-greeter`) is **archived/readonly** and ships no
  patches past 2021 (its Void template is `lightdm-webkit2-greeter 2.2.5r6`).
- It renders its HTML/JS theme through the `webkit2gtk` engine. Newer
  webkit2gtk changed webkit **web-extension file-descriptor inheritance**
  (WebKit/WebKit#4868), which breaks the greeter's IPC to the LightDM daemon —
  an intermittently-reappearing, **vendor-independent** breakage (Arch
  forum threads across 2022–2024; black screen with cursor is the canonical
  signature). It is NOT caused by the installer's greeter config (GTK/Slick
  boot fine and use the same lightdm.conf / accounts-daemon service).
- The `WEBKIT_DISABLE_DMABUF_RENDERER=1` workaround from Arch FS#79783 is
  **NVIDIA-only** (a DMABUF bug) and does not help the AMD/or the
  abandoned-IPC case generally.
- The maintained WebKit-based successors (`web-greeter`, `nody-greeter`,
  `sea-greeter` by JezerM) work, but **none is in Void's official repos**
  (no `srcpkgs/*`; third-party templates / `xbps-src` builds only), so a
  stock-Void install cannot provide a working theme-based greeter without a
  heavy third-party build the installer will not ship.

**Decision (Beta-v2.9.1 `[GREETER-NO-WEBKIT2]`):** removed the WebKit2 greeter
option from the LightDM chooser, leaving GTK + Slick (both official Void
packages that boot reliably). The abandoned greeter's `webkit-theme=void`
config block was deleted and the [LIGHTDM-HW] comment re-annotated.

**Retest ask (on the target medium):** reinstall with
`LIGHTDM_GREETER=slick` (the closest look/feel to WebKit2) and confirm the
greeter boots to desktop; confirm no `lightdm-webkit2-greeter.conf` is
generated. If a user specifically wants an HTML/JS web-theme greeter, the
documented path is third-party `nody-greeter`/`web-greeter` from a
`xbps-src` build — intentionally out of scope for the stock installer.

Log the retest outcome below before considering this fully closed.