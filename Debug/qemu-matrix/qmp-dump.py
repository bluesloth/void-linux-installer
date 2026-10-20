import json, socket, sys, time

sock, out = sys.argv[1], sys.argv[2]
time.sleep(float(sys.argv[3]) if len(sys.argv) > 3 else 0)

# Every read is bounded: QMP can sit silent (busy guest, half-negotiated
# session) and an unbounded readline() here would hang the caller for ever.
s = socket.socket(socket.AF_UNIX)
s.settimeout(20)
s.connect(sock)
try:
    f = s.makefile("rw", encoding="utf-8")
    f.readline()                                  # greeting
    f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n")
    f.flush()
    print("caps:", f.readline().strip())
    f.write(json.dumps({"execute": "screendump", "arguments": {"filename": out}}) + "\n")
    f.flush()
    for _ in range(5):
        try:
            line = f.readline()
        except socket.timeout:
            break
        if not line:
            break
        print("reply:", line.strip())
        if '"return"' in line or '"error"' in line:
            break
    f.close()
finally:
    s.close()
