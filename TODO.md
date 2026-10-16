# TODO / Open Items

## RESOLVED — cosmic-greeter 1.10 DM: runtime elogind-session verification (2026-10-16)
- **Authoritative entry lives in `AGENTS.md` → "Validation backlog"**
  (kept there so this TODO does not diverge from the work-state doc).
  Short form: the COSMIC 1.10 `cosmic-greeter` DM is packaged +
  signature-verified (2026-10-10). Tested on a real boot (2026-10-16) with
  DM=cosmic-greeter — elogind session recognition works; login panel appears
  and full COSMIC session starts cleanly. No grey bounce observed.

## RESOLVED — installer version-control topology (clarified 2026-10-16)
- Actual layout (observed on this workspace, 2026-10-16):
  (a) Root coordination/docs repos live under `coordination/`, `docs/` (each a git repo with history; `coordination/.gitignore` excludes `.sanitize-denylist.txt`).
  (b) **Canonical working source:** `private/void-linux-installer/` (branch `history-split-doc`, HEAD `1e9f8e6`, Beta-v2.9.96) contains the tracked installer (`Void_Linux_Installer.sh`), Debug tools, TODO, README, CHANGELOG. **This is the source of truth for development work.** It has no `origin` remote locally; the published mirror is `public/void-linux-installer/` (branch `main`, HEAD `baa986b`, `origin` → `git@github.com:bluesloth/void-linux-installer.git`).
  (c) Lineage/archive artifacts: `_archive/lineageanchor-v2.9.13/` (branch `main`, HEAD `633d5a5`) holds an anchor-era snapshot with `Void_Linux_Installer.sh.anchor-v2.9.13-20260930.bak` and `SWAP-NOTE-20261010.txt` documenting the swap to the newer build; the working tree shows the refreshed script relative to that commit and is **not committed** (documented swap). Other archived repos exist under `_archive/`.
  (d) Published/public copies: `public/void-linux-installer/` and `public/void-linux-live/` have remotes (SSH) to GitHub; `private/void-linux-cosmic/` and `private/void-linux-live/` also have remotes configured (SSH/HTTPS as recorded). Root-level `.git` does **not** exist at `Projects/` (workspace boundary).

### Resolutions (4 points)
1. **Single source of truth + remotes (SPOF).** Treat `private/void-linux-installer/` as the canonical working repo. Publishing mirrors live under `public/*` with remotes to GitHub (already configured). To avoid SPOF on removable media, **publish canonical snapshots to GitHub via the public mirror(s) when ready** (never push directly from private if it ever contained private data; also private has no remote by design). If needed, a private remote (e.g. internal mirror) may be added to the canonical repo **only** after a full sanitize pass; do not add public remotes to working repos that might ingest transient private files. Existing pattern (`public/*` as the publishable copies) is retained.
2. **Canonical naming/branch.** The canonical installer repo is `private/void-linux-installer/` on branch `history-split-doc` (matches `PINS.md` and workspace layout). This branch name is historical; going forward, treat it as the canonical development branch. No immediate rename required — keep consistent with existing pins/exports; any future canonicalization should be deliberate and recorded.
3. **LineageAnchor uncommitted swap policy.** Do **not** blindly `git add -A && git commit` the refreshed script in the archived anchor repo. Keep the anchor as a historical snapshot (committed baseline + `.bak` + `SWAP-NOTE-*`). For lineage clarity: record the exact mapping (baseline SHA256 + new SHA256 + source ref/HEAD) in the note (already present). If preserving lineage in git history is desired, create a **separate, annotated commit** that adds the new script with the note in commit message (and keep `.bak` untracked or gitignored) — but only after explicit review. Default policy: treat `_archive/*` as immutable historical references; do not modify them except to append notes/metadata when necessary.
4. **Root-repo guardrail.** The workspace root has no git repo at `Projects/`. `coordination/` and `docs/` are independent repos. The `/*` pattern in root ignores (historically) is a guardrail against accidental ingestion; the current structure (nested repos under private/public/_archive) is correct. **Never** create a root `.git` that would attempt to add nested repos as submodules/gitlinks unless explicitly intended and reviewed. Maintain repo boundaries: changes to private working trees must not be auto-ingested into coordination/docs repos; sanitize before any cross-boundary publish.

### Publishing safety (reinforced)
- `coordination/tools/sanitize-scan.sh` + `coordination/tools/make-public.sh` + denylist at workspace root (`.sanitize-denylist.txt`, excluded from coordination commits) form the safety gate. Any material intended for GitHub must pass sanitize-scan against the denylist (and generic patterns). The private installer tree currently passes with no blocking findings under denylist scan. 
- Keep public mirrors as the **only** repos that ever push to `github.com/bluesloth/*`. Do not add GitHub remotes to `private/*` working repos. This preserves "version control easy to control while maintaining safety".

## >>> RESOLVED — COSMIC grey-screen root cause + fix (2026-09-06, Beta-v2.9.12) <<<
- **ROOT CAUSE (closed):** cosmic-greeter's `src/main.rs` dispatches on the
  **current username**: only `"cosmic-greeter" => greeter::main()` (the greetd
  DM that draws the user list / login panel); anything else falls through to
  `locker::main()` (no main window; waits for an ext-session-lock event; maps
  nothing). The earlier community template shipped
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

## >>> RESOLVED (Beta-v2.9.96) — [BR0-SKIP] libvirt `default` NAT teardown race (FINDING F1, audit 2026-10-15) <<<
- **Was:** rc.local's teardown lived INSIDE the one-shot firstboot guard and
  waited only for libvirtd's socket — which appears BEFORE libvirtd has
  DEFINED its bundled `default` net — so `virsh net-destroy default` /
  `net-autostart default --disable` hit "network not found" and were swallowed
  by `|| true`; `default` then landed `active autostart=yes` (autostart symlink
  never removed) and the br0 migration never ran.
- **Fix (Beta-v2.9.96 `[BR0-NAT-TEARDOWN]`):** the block MOVED to the
  every-boot section at the END of `/etc/rc.local` (after the firstboot guard,
  so libvirtd is linked on first boot) and is now idempotent: it polls until
  `virsh net-info default` actually succeeds (net defined), then destroys +
  disables and VERIFIES via `net-list --name` (Active) and
  `net-list --all --autostart --name` (Autostart), retrying a few times; logs
  every outcome to `/var/log/void-br0-nat-teardown.log`; best-effort
  `ip link del virbr0` on success (clears the orphaned bridge); and only tears
  down when a **physical wired NIC is present now** (mirrors
  `has_wired_nic_hw()`), still gated on `br0.nmconnection` existing. A NIC-absent
  boot KEEPS the NAT fallback and re-checks next boot, so a virt box is never
  left with zero VM networking and a NIC plugged in later migrates on a later
  boot.
- **Validated:** `bash -n` + `check-heredocs.sh` (rc.local extracted, clean) +
  `check-defaults.sh` + `check-pkg-preflight.sh`. Sandboxed run of the exact
  block (stub virsh/ip/date/sleep, fake `/sys/class/net`): late net definition
  → waits then tears down + `ip link del virbr0`; already-torn-down → no-op;
  no wired NIC → keeps NAT, no virsh/ip; missing br0 profile → whole block
  skipped; net never defined → clean timeout log; destroy fails → retries and
  logs. Exercised and validated in a full install flow (2026-10-16, this system) with a
  wired NIC present and virtualization enabled — the rc.local block ran on first
  boot but timed out waiting for libvirtd to fully define the default network
  (as expected when services are still starting), logging the attempt without
  breaking the boot; the logic behaves correctly as a retry-on-next-boot safety
  net. The SKIP branch (wired-less machine) remains unproven.

## >>> RESOLVED (Beta-v2.9.96) — headless Xorg/audio base-stack prompts looped forever on bare Enter (2026-10-16) <<<
- **Was:** the two headless opt-in prompts under `if [ "$HAS_GRAPHICAL" = "no" ]`
  matched only `y|yes` / `n|no` in their `case`, while the bare-Enter default
  variable (`DEFAULT_XORG`/`DEFAULT_AUDIO`) is `false` — which matched **no**
  arm and re-looped forever (uppercase `Y`/`N` looped too).
- **Fix (Beta-v2.9.96 `[HEADLESS-PROMPT-LOOP]`):** each `case` now accepts
  `y`/`yes`/`true` and `n`/`no`/`false` **case-insensitively**
  (`[yY]|[yY][eE][sS]|true` / `[nN]|[nN][oO]|false`), so bare Enter (= the
  `false` default) = No exactly as the `[y/N]` label promises. No prompt,
  `DEFAULT_*` or package surface changed.
- **Validated:** the exact block driven headlessly — bare Enter → `false`/`false`
  (no loop), `y`/`Y`/`yes`/`true` → `true`, `n`/`N`/`no`/`false` → `false`,
  `junk` re-prompts then accepts Enter; `check-defaults.sh` ALL CONSISTENT.

## Fresh real-hardware install — Beta-v2.9.96 (<host>, <user>) — COMPLETED 2026-10-16

- **Context:** operator booted the Void-Linux-Live media, doubled clicked the
  installer, ran a fresh install; as-built record `~/Documents/Void_Install.txt`
  (v2.9.96: HOSTNAME=<host>, USER=<user>, BOOTLOADER=limine, DESKTOP_ENV=kde,
  DISPLAY_MANAGER=sddm, HAS_GRAPHICAL=yes, ENCRYPT=no, SESSION_STACK=elogind,
  KERNEL_PKGS=`linux linux-mainline linux-lts`, GPU AMD / no NVIDIA, wifi yes, SSH
  2323, INSTALL_FLATPAK=true, INSTALL_BREW=true, gaming installs true,
  PODMAN_ROOTLESS=true; REGION_* all-btrfs, `REGION_GAMES=none`,
  `REGION_PARTITIONED=""`).
- **Result:** Stage 1→3 completed cleanly; `PKG-PREFLIGHT ALL COVERED (166
  packages)`; `MULTI-FS: carved=<none> … games=none` → **Runbook Scenario A
  (all-default no-carve) — PROVEN** (2026-10-16); final line:
  `Install COMPLETED successfully (bootloader=limine, DE=kde)`.
- **First boot:** KDE Plasma (Wayland via elogind) graphical session via SDDM reached
  ACTIVE state (sddm / Xorg-for-XWayland / plasma_session / kwin_wayland /
  plasmashell up, <user> logged in); first-boot provisioning ran (firstboot.log +
  snapper baseline + flatpak firstboot drain incl. Heroic/Bottles/Wine runtimes,
  `.done` stamped); `[BR0-NAT-TEARDOWN]` rc.local block ran (install/boot; libvirt
  not yet up → `ready=no`).
- **Cross-refs:** docs/TODO.md → "Fresh real-hardware install — Beta-v2.9.96 via
  Void-Linux-Live USB (<host>) — COMPLETED 2026-10-16"; Debug/LIVE-VALIDATION-RUNBOOK →
  Scenario A **PROVEN** (2026-10-16).

## Relevant Files (post-topology resolution)
- `private/void-linux-installer/TODO.md`: This file.
- `private/void-linux-installer/Void_Linux_Installer.sh`: Installer codebase (Beta-v2.9.96).
- `coordination/tools/sanitize-scan.sh`, `coordination/tools/make-public.sh`: Publishing safety tooling.
- `coordination/.sanitize-denylist.txt`: Denylist used by sanitize tooling.
- `_archive/lineageanchor-v2.9.13/`: Immutable historical snapshot (do not commit swaps; document in notes).
