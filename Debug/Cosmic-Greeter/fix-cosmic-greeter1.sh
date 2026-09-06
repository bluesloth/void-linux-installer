#!/bin/sh
# Idempotent live repair of the cosmic-greeter DM on a Beta-v2.9.9 COSMIC
# install, mirroring the Beta-v2.9.10 [COSMIC-GREETER-DM] recipe byte-for-byte
# so this IS the hardware validation of the new greetd-hosted path.
# Trigger: sudo bash ~/fix-cosmic-greeter.sh   (then reboot, or log out of tty1)
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

echo ""
echo "DONE. Reboot to let greetd take tty1, or log out of tty1 so the already-"
echo "supervised cosmic-greeter service can start greeterd on the free VT."