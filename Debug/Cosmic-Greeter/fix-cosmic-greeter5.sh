#!/bin/sh
# Idempotent live repair of the cosmic-greeter DM on a Beta-v2.9.9 COSMIC
# install, mirroring the Beta-v2.9.10 [COSMIC-GREETER-DM] + Beta-v2.9.11
# [COSMIC-GREETER-LOG] recipe so this IS the hardware validation of the
# greetd-hosted path.
#
# v5 (2026-09-06): the greetd-launched greeter session now runs inside a
#   session D-Bus (dbus-run-session). Diagnostic #1 of the grey-screen
#   (clean boot, sole _cosmicgreeter seat session on tty1) showed every
#   greeter start failing with:
#     cosmic_comp::dbus: Failed to initialize session DBus connection:
#       I/O error: No such file or directory (os error 2)
#     cosmic_comp: Failed to update the D-Bus activation environment:
#       org.freedesktop.zbus.Error: i/o error
#   Only the SYSTEM dbus (runsv dbus) was running; the greeter is designed
#   to run "inside cosmic-comp" (i.e. under a COSMIC session, which supplies
#   the session bus), but our bare greetd wrapper provided none. The iced/
#   wgpu login panel almost certainly depends on that session bus to map as a
#   layer. This v5 wraps the greeter exec in `dbus-run-session --` so
#   DBUS_SESSION_BUS_ADDRESS is set for the whole compositor+greeter tree.
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

# 2. greetd config (identical to installer bake). The greeter app + compositor
#    are run by greetd's session-worker as a DETACHED process tree, so runit's
#    svlogd can NEVER capture their stderr (greetd doesn't pipe session output
#    to the service's log). Upstream discards it to /dev/null; here we make the
#    greetd command a wrapper that tees compositor+greeter output to a file the
#    _cosmicgreeter user can write (/var/log/cosmic-greeter-session.log), which
#    is what finally reveals why the iced login panel fails to surface.
mkdir -p /etc/greetd
cat > /etc/greetd/cosmic-greeter.start << 'EOF'
#!/bin/sh
# v5 [COSMIC-GREETER-SESSION-BUS]: run the whole compositor+greeter tree
# inside a session D-Bus. cosmic-greeter is built to run "inside cosmic-comp"
# (i.e. under a COSMIC session that provides DBUS_SESSION_BUS_ADDRESS); a bare
# greetd spawn had no session bus, so cosmic_comp could not init its session
# DBus nor update the activation environment, and the iced login panel never
# mapped as a layer (grey + cursor only). The session bus is now delegated to
# dbus-run-session, which also keeps the daemon supervisable (greetd execs a
# single direct child).
exec dbus-run-session -- cosmic-comp cosmic-greeter >> /var/log/cosmic-greeter-session.log 2>&1
EOF
chmod 0755 /etc/greetd/cosmic-greeter.start
install -d -m0755 -o root -g root /var/log
touch /var/log/cosmic-greeter-session.log
chown _cosmicgreeter:_cosmicgreeter /var/log/cosmic-greeter-session.log
chmod 0644 /var/log/cosmic-greeter-session.log
cat > /etc/greetd/cosmic-greeter.toml << 'EOF'
[terminal]
vt = "1"

[general]
service = "cosmic-greeter"

[default_session]
command = "/etc/greetd/cosmic-greeter.start"
user = "_cosmicgreeter"
EOF
chmod 0644 /etc/greetd/cosmic-greeter.toml
echo "wrote /etc/greetd/cosmic-greeter.toml + /etc/greetd/cosmic-greeter.start"
echo "compositor/greeter session output will land in /var/log/cosmic-greeter-session.log"

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

# 7. Restart the four runit units: the two services AND their /log sub-services.
#    `sv restart cosmic-greeter` alone does NOT re-exec the log/run — a stale
#    vlogger from boot would keep pumping greeter output to the void while the
#    new svlogd starves. Restarting the /log supervisor forces runsv to re-read
#    the freshly-written svlogd run body.
sv restart cosmic-greeter-daemon/log cosmic-greeter/log 2>&1 || true
sv restart cosmic-greeter-daemon cosmic-greeter 2>&1 || true

# 8. Wait for greetd to relaunch the greeter stack (fresh PID), then snapshot
#    both svlogd 'current' files AND the new session capture into ONE triage
#    txt so the grey-screen evidence lands automatically — no manual tail.
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
    echo "--- /var/log/cosmic-greeter-session.log (compositor + greeter app stderr) ---"
    tail -n 200 /var/log/cosmic-greeter-session.log 2>/dev/null || echo "(no output captured yet)"
    echo "--- /var/log/cosmic-greeter/current (runit service log, daemon-branch) ---"
    tail -n 200 /var/log/cosmic-greeter/current 2>/dev/null || echo "(no output captured yet)"
    echo "--- /var/log/cosmic-greeter-daemon/current (daemon service log) ---"
    tail -n 200 /var/log/cosmic-greeter-daemon/current 2>/dev/null || echo "(no output captured yet)"
    echo "=== end triage ==="
} >> "$triage"
chmod 0644 "$triage"

echo ""
echo "================================================================"
echo "Triage written to:  $triage"
echo "Persistent logs:"
echo "  /var/log/cosmic-greeter-session.log  (compositor + greeter app stderr)"
echo "  /var/log/cosmic-greeter/current      (greetd service log)"
echo "  /var/log/cosmic-greeter-daemon/current (daemon service log)"
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
echo "  - greetd runs the greeter/compositor as a DETACHED session-worker tree,"
echo "    so runit's svlogd can never capture their stderr — upstream discards it"
echo "    to /dev/null. This script regenerates /etc/greetd/cosmic-greeter.start"
echo "    to tee it to /var/log/cosmic-greeter-session.log (0644, world-readable)."
echo "    The deployed /etc/greetd/cosmic-greeter.toml points its default_session"
echo "    command at that wrapper, so the capture survives reboots."
echo "  - The triage snapshot (triage txt) includes that session log + both"
echo "    svlogd 'current' files. The script waits ~10-40s for the fresh greetd"
echo "    worker to relaunch 'cosmic-comp cosmic-greeter' before snapshooting,"
echo "    so startup render/surface errors are included."
echo "  - v5 wraps that wrapper in `dbus-run-session --` ([COSMIC-GREETER-"
echo "    SESSION-BUS]). Live diagnosis was conclusive on this point: every greeter"
echo "    start (incl. the clean reboot at 10:54/14:54) failed cosmic_comp"
echo "    session-DBus init + D-Bus activation-environment update with os error 2"
echo "    (No such file or directory) because only the system bus was running."
echo "    That is the leading explanation for the login panel never mapping as a"
echo "    layer."
echo "  - Secondary avenue (only if the session-bus change still leaves it grey):"
echo "    install the Vulkan stack and retest —"
echo "    sudo xbps-install -Sy vulkan-loader mesa-vulkan-radeon"
echo "    (radeonsi ICD; LLVMPIPE fallback means this is not strictly required,"
echo "    but cosmic-comp prefers it). Then 'sudo sv restart cosmic-greeter'."
echo "================================================================"
echo ""
echo "DONE. The freshly-restarted cosmic-greeter + cosmic-greeter-daemon"
echo "services are now logging to /var/log/cosmic-greeter{,-daemon}/current."
echo "Reboot to let greetd take tty1 cleanly, or rely on the restart above."