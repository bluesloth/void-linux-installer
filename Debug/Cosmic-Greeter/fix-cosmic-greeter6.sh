#!/bin/sh
# Idempotent live repair of the cosmic-greeter DM on a Beta-v2.9.9 COSMIC
# install, mirroring the Beta-v2.9.10 [COSMIC-GREETER-DM] + Beta-v2.9.11
# [COSMIC-GREETER-LOG] recipe so this IS the hardware validation of the
# greetd-hosted path.
#
# v6 (2026-09-06): SEATD ROUTE for the grey-screen. Diagnoses #1-#5 (clean
#   boots, sole _cosmicgreeter seat session on tty1, session D-Bus restored in
#   v5) all reproduce the SAME final failure: cosmic-comp starts UNPRIVILEGED:
#     cosmic_comp::compositor: Failed to load graphic environment:
#       Unable to become drm master, assuming unprivileged mode
#   Debugfs (cosmic-greeter-drm-master-probe.sh) has now proven WHO holds
#   master on /dev/dri/card0: elogind's own session-device fd (dev 0,
#   master=y) — elogind's logind-session-device.c runs `sd_drmsetmaster` /
#   DRM_IOCTL_SET_MASTER (with a 20x10ms retry loop) on the seat's card0 fd
#   at session activation and KEEPS it master for the life of the session.
#   smithay's acquire_master_lock() then always gets EBUSY (16) and latches
#   `privileged=false` forever (it never re-attempts master — chvt ping-pong
#   is useless). Result: all atomic commits to card0 fail; the greeter GPU
#   composite never surfaces; grey + cursor only.
#
#   Fix: route the greeter through seatd. Void's seatd daemon (build-option
#   elogind; service `/usr/bin/seatd -g _seatd`) runs as ROOT, opens
#   /dev/dri/card0 itself and calls drm_set_master on that fd AS ROOT (seatd
#   seat.c seat_open_device), so it is unhindered by elogind AND by the
#   non-root ACL on card0. libseat prefers backends in order seatd -> logind
#   -> builtin (seatd libseat.c impls[]), so as soon as /run/seatd.sock
#   exists and _cosmicgreeter can connect (group _seatd), the greeter stops
#   using elogind's TakeDevice path entirely and no longer collides with
#   elogind's master grab.
#
# Trigger: sudo bash ~/fix-cosmic-greeter6.sh
set -eu

# 1. Install seatd (idempotent; Void 0.9.3_1, elogind build-option). Its
#    post_install runs `vsv seatd`, so /etc/sv/seatd{,/log} already exist.
if ! command -v seatd >/dev/null 2>&1; then
    echo "installing seatd..."
    xbps-install -y seatd
else
    echo "seatd already installed ($(seatd -v 2>&1 || true))"
fi

# 2. _cosmicgreeter must reach /run/seatd.sock (root:_seatd 0660) so libseat
#    can switch backends; keep its existing video,input memberships.
if ! grep -q '^_seatd:' /etc/group 2>/dev/null; then
    echo "WARNING: '_seatd' group missing; the seatd package post_install "
    echo "         should have created it. Aborting before complicating things."
    exit 1
fi
if ! id -nG _cosmicgreeter 2>/dev/null | tr ' ' '\n' | grep -qx '_seatd'; then
    usermod -aG _seatd _cosmicgreeter
    echo "added _cosmicgreeter to _seatd group"
else
    echo "_cosmicgreeter already in _seatd group"
fi

# 3. Supervise seatd (Void ships /etc/sv/seatd) - persist across reboot.
#    Rewrite seatd's log/run: the package's vsv-generated vlogger -t writes to
#    syslog, and this box has NO syslog daemon (same reason v5 fixed
#    cosmic-greeter's log/run) - direct svlogd keeps the daemon's master/
#    open-device lines for the triage evidence.
if [ ! -e /etc/sv/seatd/run ]; then
    echo "ERROR: /etc/sv/seatd/run missing even though seatd is installed." >&2
    exit 1
fi
mkdir -p /etc/sv/seatd/log
cat > /etc/sv/seatd/log/run << 'EOF'
#!/bin/sh
exec svlogd -tt /var/log/seatd
EOF
chmod 0755 /etc/sv/seatd/log/run
install -d -m0750 -o root -g root /var/log/seatd
ln -sfn /etc/sv/seatd /etc/runit/runsvdir/default/seatd
echo "linked seatd into runsvdir default (log/run -> direct svlogd /var/log/seatd)"
sv restart seatd/log seatd 2>&1 || true
# Wait briefly for the socket then verify ownership/perms.
for i in $(seq 1 20); do
    [ -S /run/seatd.sock ] && break
    sleep 0.5
done
if [ -S /run/seatd.sock ]; then
    echo "seatd socket: $(stat -c '%A %U:%G %n' /run/seatd.sock)"
else
    echo "WARNING: /run/seatd.sock not present after start - check service state." >&2
fi

# 4. Restart the greeter stack so libseat re-inits and picks the seatd backend
#    (first in its backend order) instead of elogind's TakeDevice path.
if [ -d /var/service/cosmic-greeter ]; then
    sv restart cosmic-greeter-daemon cosmic-greeter 2>&1 || true
    echo "restarted cosmic-greeter-daemon + cosmic-greeter through seatd"
else
    echo "WARNING: no /var/service/cosmic-greeter (services not linked yet)?" >&2
fi

# 5. Snapshot the DRM master state (debugfs) + greeter output + service logs
#    into one triage txt before/after the restart so the seatd switch's effect
#    lands automatically — no manual tail.
triage=/var/log/cosmic-greeter-triage6.txt
: > "$triage"
if ! mountpoint -q /sys/kernel/debug 2>/dev/null; then
    mount -t debugfs none /sys/kernel/debug 2>/dev/null || true
fi
debugfs_clients=/sys/kernel/debug/dri/0/clients
{
    echo "=== cosmic-greeter triage6 (seatd route): $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
    echo "--- seatd service state ---"
    sv status seatd 2>&1 || true
    echo "--- /run/seatd.sock ---"
    stat -c '%A %U:%G %n' /run/seatd.sock 2>&1 || true
    echo "--- DRM card0 clients BEFORE greeter relaunch (elogind holds master? cosmic-comp?) ---"
    cat "$debugfs_clients" 2>&1 || echo "(debugfs not available)"
    echo "--- greeter session log tail ---"
    tail -n 60 /var/log/cosmic-greeter-session.log 2>/dev/null || echo "(no session log)"
    echo "--- cosmic-greeter svlogd tail ---"
    tail -n 60 /var/log/cosmic-greeter/current 2>/dev/null || echo "(no svlogd)"
} >> "$triage"

echo "waiting for greetd to relaunch the greeter stack..."
for i in $(seq 1 30); do
    pgrep -f 'cosmic-comp cosmic-greeter' >/dev/null 2>&1 && break
    sleep 1
done
if pgrep -f 'cosmic-comp cosmic-greeter' >/dev/null 2>&1; then
    echo "greeter relaunched; letting it emit startup output (~8s)..."
    sleep 8
else
    echo "WARNING: cosmic-comp/cosmic-greeter did NOT relaunch within 30s." >&2
fi
{
    echo "--- DRM card0 clients AFTER greeter relaunch (cosmic-comp should now be master=y) ---"
    cat "$debugfs_clients" 2>&1 || echo "(debugfs not available)"
    echo "--- greeter session log tail after relaunch ---"
    tail -n 60 /var/log/cosmic-greeter-session.log 2>/dev/null || echo "(no session log)"
    echo "--- seatd daemon log tail ---"
    tail -n 60 /var/log/seatd/current 2>/dev/null || echo "(no seatd svlogd)"
    echo "=== end triage6 ==="
} >> "$triage"
chmod 0644 "$triage"

echo ""
echo "================================================================"
echo "Triage written to:  $triage"
echo "Master-state evidence:"
echo "  BEFORE: elogind (dev 0, master=y) <-- the persistent DRM master blocker"
echo "  AFTER : cosmic-comp (dev 0) should now read master=y"
echo "================================================================"
echo "Grey-screen diagnosis (this route):"
echo "  - v5 confirmed the session D-Bus is no longer the missing piece."
echo "  - drm-master-probe proved elogind's session-device fd holds DRM master"
echo "    on card0 (debugfs clients: elogind master=y, cosmic-comp master=n)"
echo "    and an independent SET_MASTER gets EBUSY 16."
echo "  - smithay latches is_privileged at DrmDeviceFd::new(); activate() only"
echo "    re-arms master if is_privileged(), so an unprivileged greeter never"
echo "    recovers on VT switch (option 'probe chvt' conclusively dead)."
echo "  - THIS route installs seatd and starts it; libseat then uses the seatd"
echo "    backend (first in its order) instead of elogind. seatd runs as root,"
echo "    opens card0 itself and drm_set_master()s it as root, so neither the"
echo "    elogind collision nor the card0 ACL stands in its way."
echo "================================================================"
echo ""
echo "DONE. If the AFTER debugfs shows cosmic-comp master=y AND the login"
echo "panel surfaces, promote seatd into the Void_Linux_Installer under the"
echo "COSMIC branch ([COSMIC-SEATD], Beta-v2.9.12)."