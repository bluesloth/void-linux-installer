#!/usr/bin/env python3
"""
expect-style driver for a QEMU serial unix socket.

usage: serial-expect.py <socket> <logfile> <session-file>

session file directives (one per line):
  wait <python-regex> [timeout_secs]   block until output matches (else exit 3)
  send <literal text>                  write text; \\n and \\t are unescaped
  sleep <secs>                         pause
  # comment

Everything the guest emits is appended to <logfile>. Matching is done against
the accumulated log (so patterns can span reads), and the scan position only
ever moves forward.
"""
import re
import socket
import sys
import time

sock_path, log_path, script_path = sys.argv[1], sys.argv[2], sys.argv[3]

s = socket.socket(socket.AF_UNIX)
s.connect(sock_path)
s.settimeout(0.5)

log = open(log_path, "ab", buffering=0)
seen = b""          # all bytes received so far (for matching)
scan = 0            # how far we've matched already
t_log = time.time()


def pump(deadline):
    """Receive until <deadline> (epoch), appending to seen/log."""
    global scan
    while time.time() < deadline:
        try:
            data = s.recv(8192)
        except socket.timeout:
            continue
        if not data:
            return False
        log.write(data)
        seen_local = seen + data  # noqa: F841  (kept simple: rebuild in caller)
        globals()['seen_bytes'] = seen + data
        return_extra = data
        # fold into seen
        _grow(data)
        return True
    return False


def _grow(data: bytes):
    global seen
    seen += data


def recv_until(deadline):
    while time.time() < deadline:
        try:
            data = s.recv(8192)
        except socket.timeout:
            continue
        if not data:
            return False
        log.write(data)
        _grow(data)
    return True


def do_wait(pat, timeout):
    global scan
    rx = re.compile(pat.encode())
    deadline = time.time() + timeout
    while True:
        m = rx.search(seen, scan)
        if m:
            scan = m.end()
            return True
        if time.time() >= deadline:
            sys.stderr.write("TIMEOUT waiting for: %s\n" % pat)
            sys.stderr.write("tail of log: %r\n" % seen[-600:])
            return False
        before = len(seen)
        recv_until(min(deadline, time.time() + 0.5))
        if len(seen) == before and time.time() >= deadline:
            sys.stderr.write("TIMEOUT waiting for: %s\n" % pat)
            sys.stderr.write("tail of log: %r\n" % seen[-600:])
            return False


for raw in open(script_path, "r", encoding="utf-8"):
    line = raw.rstrip("\n")
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    parts = line.split(None, 1)
    cmd = parts[0]
    arg = parts[1] if len(parts) > 1 else ""
    if cmd == "wait":
        bits = arg.rsplit(None, 1)
        if len(bits) == 2 and re.fullmatch(r"[0-9]+\.?[0-9]*", bits[1]):
            pat, to = bits[0], float(bits[1])
        else:
            pat, to = arg, 60.0
        if not do_wait(pat, to):
            sys.exit(3)
    elif cmd == "send":
        s.sendall(arg.replace("\\n", "\n").replace("\\t", "\t").encode())
    elif cmd == "sleep":
        recv_until(time.time() + float(arg))
    else:
        sys.stderr.write("unknown directive: %s\n" % cmd)
        sys.exit(2)

# drain briefly so the last response lands in the log
recv_until(time.time() + 3)
s.close()
log.close()
print("session ok")
