import fcntl, os, struct

CARD = "/dev/dri/card0"

# Exact libdrm ioctl numbers (base 'd' = 0x64):
DRM_IOCTL_GET_MAGIC   = 0x80046406  # _IOR ('d',0x06, struct drm_auth{__u32}) size=4
DRM_IOCTL_SET_MASTER  = 0x0000641E  # _IO  ('d',0x1e) - no args
DRM_IOCTL_DROP_MASTER = 0x0000641F  # _IO  ('d',0x1f) - no args

fd = os.open(CARD, os.O_RDWR | os.O_CLOEXEC)
print(f"opened {CARD} fd={fd}")
try:
    buf4 = bytearray(4)
    fcntl.ioctl(fd, DRM_IOCTL_GET_MAGIC, buf4)
    print(f"GET_MAGIC: ok (0x{struct.unpack_from('I', buf4, 0)[0]:08x}) -> valid DRM primary fd")

    try:
        fcntl.ioctl(fd, DRM_IOCTL_SET_MASTER)
        print("SET_MASTER: SUCCESS (master slot was FREE) -> dropping immediately")
        fcntl.ioctl(fd, DRM_IOCTL_DROP_MASTER)
        print("DROP_MASTER: ok")
    except OSError as e:
        print(f"SET_MASTER: FAILED {e.errno} {e.strerror}")
        print("  => something else holds the DRM master on card0 right now")
finally:
    os.close(fd)
