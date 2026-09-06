#!/bin/bash
# cosmic-greeter libseat logind-backend probe — v1 (2026-09-06)
#
# WHY THIS EXISTS: cosmic-comp logs "Unable to become drm master, assuming
# unprivileged mode" at EVERY boot/restart, while renderD128 is world-writable
# (crw-rw-rw-) and elogind reports session 7 (greeter) Active=yes on seat0 with
# [MASTER] uaccess tags. That signature means libseat is NOT successfully
# running its logind backend for the greeter — it falls back to the unprivileged
# build-in backend, so cosmic-comp never gets a master-capable fd and cannot
# atomic-commit to card0 (no login panel).
#
# libseat's logind backend (libseat/backend/logind.c) opens the seat by, in
# order:
#   1. Manager.GetSession(XDG_SESSION_ID=7)
#   2. Session.TakeControl(false)           <- seat control handshake
#   3. Session.TakeDevice(major,minor)      <- device fd from logind
# and then the compositor ioctl(DRM_IOCTL_SET_MASTER) on that fd.
#
# This probe replays that exact sequence FROM WITHIN the greeter session's
# cgroup (so elogind resolves the caller to session 7 like cosmic-comp), and
# finally attempts SET_MASTER/DROP_MASTER on the received fd. It therefore tells
# us which libseat step fails and whether elogind would hand out DRM master at
# all. Read-only today except a momentary master grab (immediately dropped).
#
# Run as:  sudo bash ~/cosmic-greeter-libseat-probe.sh
# Writes everything to /var/log/cosmic-greeter-libseat-probe.txt (0644).
set -u

OUT=/var/log/cosmic-greeter-libseat-probe.txt
: > "$OUT"

cc=$(pgrep -x cosmic-comp | head -1)
{
    echo "===== libseat logind-backend probe: $(date '+%Y-%m-%d %H:%M:%S %Z') ====="
    echo "host: $(hostname)   uname: $(uname -r 2>/dev/null)"
    echo ""

    if [ -z "${cc:-}" ]; then
        echo "ERROR: no 'cosmic-comp' process found — greeter stack is down?"
        echo "  processes of interest:"
        pgrep -af 'greetd|cosmic-comp|dbus-run-session|cosmic-greeter' || echo "  (none)"
        echo "===== end (aborted) ====="
        exit 0
    fi

    cgrp_line=$(grep '^0::' "/proc/$cc/cgroup")
    cg=${cgrp_line#*0::}
    CGPATH=/sys/fs/cgroup$cg
    echo "cosmic-comp pid: $cc"
    echo "session cgroup (from /proc/$cc/cgroup): $cgrp_line"
    echo "re-enterable as: $CGPATH"
    echo ""

    echo "--- 0. which backend would libseat-0.9.3 even have compiled in? ---"
    ldd /usr/lib/libseat.so.1 2>/dev/null | grep -iE 'elogind|systemd' \
        || echo "(no logind linkage — libseat in this build is seatd+buildin only!)"
    echo ""

    echo "--- 1. the D-Bus sequence libseat does, replayed ALONGSIDE cosmic-comp ---"
    echo "(replaying from a helper moved into $CGPATH so elogind sees caller = session $cg)"
    echo ""

} >> "$OUT" 2>&1

# The heavy lifting runs in the greeter session cgroup so elogind's sender-session
# lookup resolves us the same way it resolves cosmic-comp.
PY=/tmp/cosmic-greeter-libseat-probe.py
cat > "$PY" <<'PYEOF'
import gi, os, errno, fcntl, sys
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib

MAN = 'org.freedesktop.login1.Manager'
SES = 'org.freedesktop.login1.Session'
LGN = 'org.freedesktop.login1'
OBJ = '/org/freedesktop/login1'

def proxy(obj, iface):
    return Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SYSTEM, Gio.DBusProxyFlags.DO_NOT_AUTO_START_AT_CONSTRUCTION,
        None, LGN, obj, iface, None)

mgr = proxy(OBJ, MAN)
try:
    r = mgr.call_sync('GetSession', GLib.Variant('(s)', ('7',)),
                      Gio.DBusCallFlags.NONE, -1, None)
    sess = r.unpack()[0]
    print('Manager.GetSession("7") ->', sess)
except Exception as e:
    print('Manager.GetSession("7") FAIL:', e)
    sys.exit(1)

sp = proxy(sess, SES)
for prop, typ in (('Active','b'), ('Controller','u'), ('Type','s'), ('Seat','s')):
    try:
        v = sp.get_property(prop)
        print('Session.%s =' % prop, v)
    except Exception as e:
        print('Session.%s FAIL:' % prop, e)

tp = proxy('/org/freedesktop/login1/seat/seat0', 'org.freedesktop.login1.Seat')
try:
    v = tp.get_property('ActiveSession')
    print('Seat.ActiveSession =', v)
except Exception as e:
    print('Seat.ActiveSession FAIL:', e)

print('-- Session.TakeControl(false) --')
try:
    sp.call_sync('TakeControl', GLib.Variant('(b)', (False,)),
                 Gio.DBusCallFlags.NONE, -1, None)
    print('TakeControl: OK (libseat step 2 would proceed)')
except Exception as e:
    print('TakeControl FAIL:', e)

print('-- Session.TakeDevice(226,0)=/dev/dri/card0 --')
fdlist = Gio.UnixFDList.new()
try:
    r, fdlist = sp.call_with_unix_fd_list_sync(
        'TakeDevice', GLib.Variant('(uu)', (226, 0)),
        Gio.DBusCallFlags.NONE, -1, fdlist, None)
    h, paused = r.unpack()
    fd = fdlist.get(h)
    print('TakeDevice: OK  fd=%d paused=%s' % (fd, paused))
    if fd < 0:
        print('(no fd returned; libseat device open would fail here)')
    else:
        print('-- ioctl(DRM_IOCTL_SET_MASTER=0x641e) on fd %d --' % fd)
        try:
            fcntl.ioctl(fd, 0x641e)
            print('SET_MASTER: SUCCESS - the greeter COULD have a master fd')
        except OSError as e:
            print('SET_MASTER FAIL: errno=%d %s' %
                  (e.errno, errno.errorcode.get(e.errno, '?')))
            f = open('/proc/self/status')
            caps = [l for l in f if l.startswith('CapEff:')][0].split()[1]
            print('  (our CapEff=0x%s — note elogind grants the fd+ACL,'
                  ' kernel grants master)' % caps)
        print('-- ioctl(DRM_IOCTL_DROP_MASTER=0x641f) (release it again) --')
        try:
            fcntl.ioctl(fd, 0x641f)
            print('DROP_MASTER: SUCCESS (master returned)')
        except OSError as e:
            print('DROP_MASTER FAIL: errno=%d %s' %
                  (e.errno, errno.errorcode.get(e.errno, '?')))
        try:
            sp.call_sync('ReleaseDevice', GLib.Variant('(uu)', (226, 0)),
                         Gio.DBusCallFlags.NONE, -1, None)
            print('ReleaseDevice: OK')
        except Exception as e:
            print('ReleaseDevice FAIL:', e)
except Exception as e:
    print('TakeDevice FAIL:', e)

try:
    sp.call_sync('ReleaseControl', GLib.Variant('()', ()),
                 Gio.DBusCallFlags.NONE, -1, None)
    print('ReleaseControl: OK')
except Exception as e:
    print('ReleaseControl FAIL:', e)

print('===== end libseat probe =====')
PYEOF

( exec bash -c 'echo $$ > "$1/cgroup.procs"; exec python3 "$2"' bash "$CGPATH" "$PY" ) >> "$OUT" 2>&1

chmod 0644 "$OUT"

echo "libseat probe written to: $OUT"
echo "Share/attach:  sudo cat $OUT"