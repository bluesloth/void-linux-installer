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

## Entry #1 — ENCRYPT boot unlock rejects the correct install-time passphrase (OPEN)

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

**Review ask (before any fix):**
- Reproduce on the target medium with an ASCII-only passphrase to rank H1 vs
  H2; then test a trailing-space passphrase to exercise H2 directly.
- Inspect the built initramfs on the target (`lsinitramfs` /
  `dracut --list-modules`) for `i18n`/`keymap` presence.
- Note in the entry which hypothesis won and the exact fix + retest result
  before marking RESOLVED. Log the outcome below.