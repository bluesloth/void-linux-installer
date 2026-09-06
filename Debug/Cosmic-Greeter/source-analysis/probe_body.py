import gi, os, errno, fcntl, sys
gi.require_version('Gio', '2.0')
from gi.repository import Gio, GLib

MAN = 'org.freedesktop.login1.Manager'
SES = 'org.freedesktop.login1.Session'
LGN = 'org.freedesktop.login1'
OBJ = '/org/freedesktop/login1'

def proxy(obj, iface):
    return Gio.DBusProxy.new_for_bus_sync(
        Gio.BusType.SYSTEM, Gio.DBusProxyFlags.DO_NOT_AUTO_START_AT_STARTUP,
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
