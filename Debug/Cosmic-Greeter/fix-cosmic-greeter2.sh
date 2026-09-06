#!/bin/sh
# Idempotent live repair of the cosmic-greeter DM on a Beta-v2.9.9 COSMIC
# install, mirroring the Beta-v2.9.10 [COSMIC-GREETER-DM] + Beta-v2.9.11
# [COSMIC-GREETER-LOG] recipe so this IS the hardware validation of the
# greetd-hosted path.
# Trigger: sudo bash ~/fix-cosmic-greeter.sh   (restarts both services, then
#           reboot, or log out of tty1)
set -eu

# 1. _cosmicgreeter system user (1.2.0-era packages shipped group only)
if ! grep -q '^_cosmicgreeter:' /etc/passwd 2>/dev/null; then
    cg_grp_opt=""
    grep -q '^_cosmicgreeter:' /etc/group 2>/dev/null && cg_grp_opt="-g _cosmicgreeter -G video,input"
    useradd -r -M -s /sbin/nologin -d /var/lib/cosmic-greeter -c 'Cosmic Greeter Account' $cg_grp_opt _cosmicgreeter
    echo "created _cosmicgreeter user"
else
    echo "_cosmicgreeter user already exists"
fi
mkdir -p /var/lib/cosmic-greeter
chown -f _cosmicgreeter:_cosmicgreeter /var/lib/cosmic-greeter

# 2. greetd config (identical to installer bake)
mkdir -p /etc/greetd
cat > /etc/greetd/cosmic-greeter.toml << 'EOF'
[terminal]
vt = "1"

[general]
service = "cosmic-greeter"

[default_session]
command = "cosmic-comp cosmic-greeter"
user = "_cosmicgreeter"
EOF
chmod 0644 /etc/greetd/cosmic-greeter.toml
echo "wrote /etc/greetd/cosmic-greeter.toml"

# 3. cosmic-greeter service -> greetd (replaces the bespoke direct exec)
#    [COSMIC-GREETER-LOG]: replace the package's `vlogger -t cosmic-greeter` log/run
#    with a direct svlogd one — there is NO syslog daemon on this box, so vlogger
#    output (the only place cosmic-greeter's own stderr went) was being DROPPED.
#    svlogd writes to a real file and survives reboot (mirrors the installer bake).
mkdir -p /etc/sv/cosmic-greeter/log
cat > /etc/sv/cosmic-greeter/run << 'EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
sv check cosmic-greeter-daemon >/dev/null || exit 1
if [ -d /var/service/elogind ]; then
    sv check elogind >/dev/null
    elogind_pid=$(cat /var/service/elogind/supervise/pid 2>/dev/null)
    for pid in $(pgrep -x 'elogind'; pgrep -x 'elogind-daemon'); do
        [ "$pid" = "$elogind_pid" ] || kill "$pid"
    done
fi
sv check elogind >/dev/null || exit 1
exec greetd -c /etc/greetd/cosmic-greeter.toml
EOF
chmod 0755 /etc/sv/cosmic-greeter/run
echo "wrote /etc/sv/cosmic-greeter/run"

# 3b. svlogd log/run + log dir for cosmic-greeter (svlogd captures greeter stderr)
install -d -m0750 -o root -g root /var/log/cosmic-greeter
cat > /etc/sv/cosmic-greeter/log/run << 'EOF'
#!/bin/sh
exec svlogd -tt /var/log/cosmic-greeter
EOF
chmod 0755 /etc/sv/cosmic-greeter/log/run
echo "wrote /etc/sv/cosmic-greeter/log/run (svlogd -> /var/log/cosmic-greeter)"

# 4. cosmic-greeter-daemon service
mkdir -p /etc/sv/cosmic-greeter-daemon/log
cat > /etc/sv/cosmic-greeter-daemon/run << 'EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
install -d -m0755 -o _cosmicgreeter -g _cosmicgreeter /run/cosmic-greeter
exec cosmic-greeter-daemon
EOF
chmod 0755 /etc/sv/cosmic-greeter-daemon/run
echo "wrote /etc/sv/cosmic-greeter-daemon/run"

# 4b. svlogd log/run + log dir for cosmic-greeter-daemon
install -d -m0750 -o root -g root /var/log/cosmic-greeter-daemon
cat > /etc/sv/cosmic-greeter-daemon/log/run << 'EOF'
#!/bin/sh
exec svlogd -tt /var/log/cosmic-greeter-daemon
EOF
chmod 0755 /etc/sv/cosmic-greeter-daemon/log/run
echo "wrote /etc/sv/cosmic-greeter-daemon/log/run (svlogd -> /var/log/cosmic-greeter-daemon)"

# 5. supervised accounts-daemon ([LIGHTDM-HW] recipe; greeter lists users via
#    org.freedesktop.Accounts, Void ships accountsservice without a service)
if [ -x /usr/libexec/accounts-daemon ]; then
    mkdir -p /etc/sv/accounts-daemon
    cat > /etc/sv/accounts-daemon/run << 'EOF'
#!/bin/sh
exec 2>&1
sv check dbus >/dev/null || exit 1
exec /usr/libexec/accounts-daemon
EOF
    chmod 0755 /etc/sv/accounts-daemon/run
    echo "wrote /etc/sv/accounts-daemon/run"
else
    echo "WARNING: accounts-daemon binary not found" >&2
fi

# 6. runsvdir default links (persist across reboot; firstboot already passed)
ln -sfn /etc/sv/cosmic-greeter-daemon /etc/runit/runsvdir/default/cosmic-greeter-daemon
echo "linked cosmic-greeter-daemon in runsvdir default"
if [ -d /etc/sv/accounts-daemon ]; then
    ln -sfn /etc/sv/accounts-daemon /etc/runit/runsvdir/default/accounts-daemon
    echo "linked accounts-daemon in runsvdir default"
fi
rm -f /etc/runit/runsvdir/default/agetty-tty1
echo "removed agetty-tty1 (frees VT 1 for greetd)"

# 7. Restart the two services so the fresh svlogd log/run bodies take effect
#    immediately (runsv picks up a log/run change on restart). The old
#    greeter that was running grey is stopped and relaunched; its output now
#    lands in /var/log/cosmic-greeter{,-daemon}/current instead of being
#    dropped by vlogger-to-nowhere.
sv restart cosmic-greeter-daemon cosmic-greeter 2>&1 || true

# 8. Wait for greetd to relaunch the greeter stack (fresh PID), then snapshot
#    both svlogd 'current' files into ONE triage txt so the grey-screen
#    evidence is captured automatically — no manual tail needed.
triage=/var/log/cosmic-greeter-triage.txt
: > "$triage"
echo "waiting for greetd to relaunch the greeter stack..."
for i in $(seq 1 30); do
    pgrep -f 'cosmic-comp cosmic-greeter' >/dev/null 2>&1 && break
    sleep 1
done
if pgrep -f 'cosmic-comp cosmic-greeter' >/dev/null 2>&1; then
    echo "greeter relaunched; letting it emit startup output (~8s)..."
    sleep 8
else
    echo "WARNING: cosmic-comp/cosmic-greeter did NOT relaunch within 30s — the greeter stack failed to start." >&2
fi
{
    echo "=== cosmic-greeter triage: $(date '+%Y-%m-%d %H:%M:%S %Z') ==="
    echo "--- /var/log/cosmic-greeter/current (last 200 lines) ---"
    tail -n 200 /var/log/cosmic-greeter/current 2>/dev/null || echo "(no output captured yet)"
    echo "--- /var/log/cosmic-greeter-daemon/current (last 200 lines) ---"
    tail -n 200 /var/log/cosmic-greeter-daemon/current 2>/dev/null || echo "(no output captured yet)"
    echo "=== end triage ==="
} >> "$triage"
chmod 0644 "$triage"

echo ""
echo "================================================================"
echo "Triage written to:  $triage"
echo "Persistent live logs (svlogd, timestamped, rotated in place):"
echo "  /var/log/cosmic-greeter/current"
echo "  /var/log/cosmic-greeter-daemon/current"
echo "================================================================"
echo "Grey-screen diagnosis:"
echo "  - Org.freedesktop.Accounts returns users (verified live on this box:"
echo "    ListCachedUsers -> User1000) and accounts-daemon is supervised, so the"
echo "    accounts UI-population cause is UNLIKELY; the greeter can enumerate users."
echo "  - The cosmetically grey screen is cosmic-comp (the compositor) itself: on"
echo "    this box cosmic-comp draws grey + cursor (LLVMPIPE software fallback; no"
echo "    Vulkan loader/ICD is installed for the AMD GPU), so compositing WORKS."
echo "    The missing piece is the greeter app's OWN login panel surfacing as a"
echo "    layer/toplevel — i.e. the iced app is alive on the system bus and is a"
echo "    wayland client but its window never maps."
echo "  - After the restart, greeter + daemon stderr (where iced logs adapter/"
echo "    surface failures) is captured automatically to:"
echo "        /var/log/cosmic-greeter-triage.txt"
echo "    (a flat snapshot of both svlogd 'current' files; the persistent live"
echo "    logs stay at /var/log/cosmic-greeter{,-daemon}/current)."
echo "    The script waits ~10-40s for the fresh greetd worker to relaunch"
echo "    'cosmic-comp cosmic-greeter' before snapshooting, so the startup"
echo "    render/surface errors are included."
echo "  - Secondary avenue (only if logs are clean): install the Vulkan stack and"
echo "    retest —   sudo xbps-install -Sy vulkan-loader mesa-vulkan-radeon"
echo "    (radeonsi ICD; LLVMPIPE fallback means this is not strictly required,"
echo "    but cosmic-comp prefers it). Then 'sudo sv restart cosmic-greeter'."
echo "================================================================"
echo ""
echo "DONE. The freshly-restarted cosmic-greeter + cosmic-greeter-daemon"
echo "services are now logging to /var/log/cosmic-greeter{,-daemon}/current."
echo "Reboot to let greetd take tty1 cleanly, or rely on the restart above."