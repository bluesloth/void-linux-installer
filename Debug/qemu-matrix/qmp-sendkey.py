#!/usr/bin/env python3
"""Type text into a QEMU guest via QMP (HMP sendkey), one key at a time.

usage: qmp-sendkey.py <qmp-socket> <text>
Special sequences: \\n -> ret, \\s -> spc, \\\\ -> backslash; a real newline
from $'...' works too. Uppercase not supported.

Escapes are decoded HERE because the harness calls this with bash single
quotes: 'testpass1\\n' arrives as the ten characters t..1, backslash, n.
The first cut looked up a REAL newline in KEYMAP, missed, and handed HMP the
line `sendkey \\` — which HMP rejects as an unknown key name — so the guest
received the password but never its Enter. Every ENCRYPT cold boot then sat at
the LUKS prompt forever, and because the caller discarded this script's output
the failure was invisible: the boot40 and boot135 screendumps were byte
identical, which is the only reason it was noticed at all.
Every QMP error is now fatal and printed, so a no-op can never hide again.
"""
import json
import socket
import sys
import time

sock_path, text = sys.argv[1], sys.argv[2]
text = text.replace("\\\\", "\x00").replace("\\n", "\n").replace("\\s", " ")
text = text.replace("\x00", "\\")

KEYMAP = {" ": "spc", "\n": "ret", "-": "minus", "_": "shift-minus",
          ".": "dot", "/": "slash", "@": "shift-2", "\\": "backslash"}

s = socket.socket(socket.AF_UNIX)
try:
    s.connect(sock_path)
except OSError as exc:
    sys.exit("qmp-sendkey: cannot connect to %s: %s" % (sock_path, exc))
f = s.makefile("rw", encoding="utf-8")
if not f.readline():                          # greeting
    sys.exit("qmp-sendkey: connection closed before the QMP greeting")


def qmp(cmd, **args):
    msg = {"execute": cmd}
    if args:
        msg["arguments"] = args
    f.write(json.dumps(msg) + "\n")
    f.flush()
    while True:
        line = f.readline()
        if not line:
            return None
        obj = json.loads(line)
        if "return" in obj or "error" in obj:
            return obj


def must(cmd, **args):
    r = qmp(cmd, **args)
    if r is None or "error" in r:
        sys.exit("qmp-sendkey: %s failed: %r" % (cmd, r))
    return r


must("qmp_capabilities")
for ch in text:
    key = KEYMAP.get(ch, ch)
    # The argument name is "command-line" (HYPHEN) — QMP rejects the Python
    # spelling "command_line" with "Parameter 'command-line' is missing". The
    # old qmp() swallowed that error, so not one key ever reached a guest:
    # the LUKS cold-boot unlock had silently never happened in any run, and
    # only the loud-failure change above exposed it. hence **{...} below —
    # a hyphen cannot be a Python keyword argument.
    must("human-monitor-command", **{"command-line": "sendkey %s" % key})
    time.sleep(0.12)
time.sleep(0.3)
s.close()
print("typed %d chars" % len(text))
