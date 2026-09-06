#!/bin/sh
# One-shot DRM-master / seat-manager diagnostic for the cosmic-greeter
# grey-screen (no login panel) on the live box.
# Run as:  sudo bash ~/cosmic-greeter-drm-diagnose.sh
#
# v1 (2026-09-06) — WHY THIS EXISTS:
#   Every boot and every in-place restart (across the session-bus fix v5 and
#   the Vulkan install) still logs:
#     smithay::backend::drm::device::fd: Unable to become drm master,
#       assuming unprivileged mode
#     smithay::backend::drm::surface::atomic: Unable to clear state: Failed to
#       commit on clear_state on /dev/dri/card0 (Permission denied)
#   That points at libseat failing to reach a SEAT BACKEND. Established facts
#   that motivate the checks below:
#     - libseat.so.1 + libelogind.so.0 are linked into cosmic-comp.
#     - seatd is NOT installed (no /run/seatd.sock, no /etc/sv/seatd) — so the
#       seatd backend is unavailable; libseat must use the elogind backend.
#     - elogind holds a HEALTHY greeter session for _cosmicgreeter (Active=yes,
#       State=active, Seat=seat0, Type=tty, Class=greeter).
#   libseat's logind backend needs, in the session environment:
#     XDG_RUNTIME_DIR, XDG_SEAT, XDG_SESSION_ID, and a DBUS_SESSION_BUS_ADDRESS
#   that elogind recognizes. If greetd didn't set XDG_SEAT/XDG_SESSION_ID,
#   libseat silently falls back to unprivileged/no-master mode. This script
#   dumps exactly those facts plus the seat/DRM inventory so the fix is
#   unambiguous.
#
# Writes everything to /var/log/cosmic-greeter-drm-diagnose.txt (0644).
set -u

diag=/var/log/cosmic-greeter-drm-diagnose.txt
: > "$diag"

{
    echo "===== cosmic-greeter DRM/seat diagnose: $(date '+%Y-%m-%d %H:%M:%S %Z') ====="
    echo "host: $(hostname)  uname: $(uname -r 2>/dev/null)"
    echo ""

    echo "--- 1. libseat / seatd / elogind packages + linkage ---"
    xbps-query -l 2>/dev/null | grep -iE 'seatd|libseat|elogind' || echo "(none matched)"
    echo "-- ldd cosmic-comp (seat-related) --"
    ldd /usr/bin/cosmic-comp 2>/dev/null | grep -iE 'seat|elogind|systemd' || echo "(no seat/elogind lib linked)"
    echo "-- seatd socket / service --"
    ls -la /run/seatd.sock 2>&1
    ls -la /etc/sv/seatd 2>&1
    sv status seatd 2>&1 || true
    echo ""

    echo "--- 2. the greetd-launched greeter session environment ---"
    wr=$(pgrep -f '^dbus-run-session -- cosmic-comp' | head -1)
    if [ -n "$wr" ] && [ -r "/proc/$wr/environ" ]; then
        echo "(reading /proc/$wr/environ — the dbus-run-session wrapper greetd spawned)"
        echo "-- XDG_*/DBUS/LIBSEAT/WAYLAND/DISPLAY --"
        tr '\0' '\n' < "/proc/$wr/environ" | grep -iE '^(XDG_|DBUS_|LIBSEAT|WAYLAND_|DISPLAY|WLR_|SD_|LANG|PATH|HOME|USER|SHELL|LOGNAME|TERM)' || echo "(none of those vars set)"
        echo "-- @LIBSEAT search path override --"
        tr '\0' '\n' < "/proc/$wr/environ" | grep -iE 'LD_LIBRARY_PATH' || echo "(no LD_LIBRARY_PATH)"
    else
        echo "WARNING: could not read the dbus-run-session wrapper environ"
        echo "  (wrapper pgrep returned: '${wr}' . A fresh greeter stack may be mid-restart.)"
        echo "-- all greetd/cosmic candidates --"
        pgrep -af 'greetd|cosmic-comp|dbus-run-session' || echo "(no matches — greeter stack is down!)"
    fi
    echo ""

    echo "--- 3. /run/user/988 (elogind runtime dir for _cosmicgreeter) ---"
    ls -la /run/user/988/ 2>&1
    echo "-- session bus / elogind artifacts --"
    ls -la /run/user/988/bus 2>&1
    ls -la /run/user/988/systemd 2>&1
    echo ""

    echo "--- 4. elogind sessions + greeter session detail ---"
    loginctl list-sessions 2>&1
    echo "-- show each seat session --"
    for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
        uid=$(loginctl show-session "$s" -p UID --value 2>/dev/null || echo '?')
        echo "session $s (uid=$uid):"
        loginctl show-session "$s" 2>/dev/null | grep -iE '^(Id|UID|User|Name|Seat|Active|State|Type|Class|VTNr|Leader)=' 
        echo "--"
    done
    echo "-- seat status --"
    loginctl seat-status seat0 2>&1
    echo ""

    echo "--- 5. DRM devices + ACL ---"
    ls -l /dev/dri/ 2>&1
    echo "-- getfacl card0 (does the active session hold uaccess?) --"
    getfacl -p /dev/dri/card0 2>&1 || setfacl --version >/dev/null 2>&1 || echo "(no getfacl/setfacl)"
    echo "-- renderD128 --"
    getfacl -p /dev/dri/renderD128 2>&1 || true
    echo ""

    echo "--- 6. greeter session log: latest drm-master / clear-state evidence ---"
    grep -aE 'drm master|clear_state|Permission denied|clear state' /var/log/cosmic-greeter-session.log 2>/dev/null | tail -8 || echo "(no matches in session log)"
    echo ""

    echo "--- 7. greetd session-worker cmdline (VT/terminal handling) ---"
    pgrep -af 'greetd --session-worker' 2>&1 || echo "(no session worker running)"
    echo "-- tty1 owner --"
    ls -la /dev/tty1 2>&1
    echo ""

    echo "===== end DRM/seat diagnose ====="
} >> "$diag" 2>&1

chmod 0644 "$diag"

echo "DRM/seat diagnostic written to: $diag"
echo "Share it as:  sudo cat $diag   (or attach the file)"