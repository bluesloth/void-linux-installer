#!/bin/sh
# One-shot diagnostic for the cosmic-greeter grey-screen on the live box.
# Run as:  sudo bash ~/cosmic-greeter-diagnose.sh
#
# v5 (2026-09-06): matches fix-cosmic-greeter5.sh / this session's v5 logs.
#   The 2026-09-06 10:54 clean-boot capture (Debug/Cosmic-Greeter/
#   cosmic-greeter-diagnose5.txt + cosmic-greeter-session-log5.log) proved:
#   - _cosmicgreeter is the sole seat session on tty1, accounts-daemon lists
#     users, and WAYLAND socket/renderD128 exist (stack healthy).
#   - Every greeter start fails cosmic_comp session-DBus init + activation
#     env update (os error 2) - NO session D-Bus in the greetd spawn. That is
#     the leading cause of the missing login panel (fixed by fix-cosmic-greeter5.sh
#     wrapping the exec in dbus-run-session --).
#   - smithay: "Unable to become drm master, assuming unprivileged mode" + the
#     periodic "clear_state ... Permission denied" recur on a clean boot too
#     (previously misread as a tty2-restart artifact).
#   - The ExpectedComma/config.ron errors are bundled-default noise; no
#     config.ron exists anywhere (config.ron lead confirmed DEAD).
#   - Vulkan still absent (no libvulkan.so.1, only virtio ICD) - secondary avenue.
#
# Writes the entire evidence bundle to /var/log/cosmic-greeter-diagnose.txt
# (world-readable 0644) so no further permission juggling is needed to read it.
#
# First grants read access to the svlogd trees so non-root can inspect the
# persistent 'current' logs directly afterwards.
set -u

diag=/var/log/cosmic-greeter-diagnose.txt

# 0. permission fix on the /var/log trees the user opted into
chmod -R a+rX /var/log/cosmic-greeter /var/log/cosmic-greeter-daemon 2>/dev/null || true
chmod 0644 /var/log/cosmic-greeter-session.log 2>/dev/null || true

: > "$diag"

{
    echo "===== cosmic-greeter diagnose: $(date '+%Y-%m-%d %H:%M:%S %Z') ====="
    echo "host: $(hostname)  uname: $(uname -r 2>/dev/null)"
    echo ""

    echo "--- 1. package versions ---"
    xbps-query -l 2>/dev/null | grep -iE 'cosmic|greetd|xwayland|vulkan|mesa|libinput|accountsservice' || echo "(xbps-query produced no matches)"
    echo ""

    echo "--- 2. root cosmic-comp config (daemon runs as root -> this is the malformed one) ---"
    if [ -d /root/.config/cosmic-comp ]; then
        ls -la /root/.config/cosmic-comp/ 2>&1
        echo "-- config.ron --"
        cat -n /root/.config/cosmic-comp/config.ron 2>&1
    else
        echo "(no /root/.config/cosmic-comp)"
    fi
    echo "-- whole /root/.config/cosmic --"
    find /root/.config/cosmic -maxdepth 2 2>/dev/null || true
    echo ""

    echo "--- 3. _cosmicgreeter config/state ---"
    find /var/lib/cosmic-greeter -maxdepth 4 2>/dev/null | sed "s#^#  #"
    echo "-- outputs.ron --"
    cat -n /var/lib/cosmic-greeter/.local/state/cosmic-comp/outputs.ron 2>&1 || echo "(no outputs.ron)"
    echo ""

    echo "--- 4. process tree ---"
    ps -eo pid,ppid,user,tty,etime,cmd 2>/dev/null | grep -iE 'greetd|cosmic|Xwayland|accounts-daemon' | grep -v grep || echo "(none found)"
    echo ""

    echo "--- 5. elogind sessions (which seat session owns DRM master?) ---"
    loginctl list-sessions 2>&1
    echo ""

    echo "--- 6. DRM devices ---"
    ls -l /dev/dri/ 2>&1
    echo ""

    echo "--- 7. listen sockets / runtime dir of _cosmicgreeter ---"
    ls -la /run/user/988/ 2>&1 || echo "(no /run/user/988)"
    echo "-- wayland sockets --"
    ls -la /run/user/988/wayland-* 2>&1
    echo "-- X11 sockets --"
    ls -la /tmp/.X11-unix/ 2>&1
    echo ""

    echo "--- 8. Vulkan/GL stack present? ---"
    ls -l /usr/lib/libvulkan*.so* 2>&1 || echo "NO libvulkan present"
    ls -l /usr/share/vulkan/icd.d/ 2>&1 || echo "(no icd.d dir)"
    echo ""

    echo "--- 9. greetd config + wrapper ---"
    ls -la /etc/greetd/ 2>&1
    echo "-- /etc/greetd/cosmic-greeter.toml --"
    cat -n /etc/greetd/cosmic-greeter.toml 2>&1
    echo "-- /etc/greetd/cosmic-greeter.start --"
    cat -n /etc/greetd/cosmic-greeter.start 2>&1
    echo ""

    echo "--- 10. runit services involved ---"
    for d in /etc/sv/cosmic-greeter /etc/sv/cosmic-greeter-daemon /etc/sv/accounts-daemon; do
        [ -d "$d" ] || continue
        echo "-- $d --"
        ls -la "$d" "$d/log" 2>&1
        echo "-- $d/run --"
        cat -n "$d/run" 2>&1
        echo "-- $d/log/run --"
        cat -n "$d/log/run" 2>&1
    done
    echo "-- link status in runsvdir default --"
    ls -la /etc/runit/runsvdir/default/ | grep -E 'cosmic|accounts|agetty|greetd' || echo "(no matching links)"
    echo ""

    echo "--- 11. greeter session log (compositor + greeter app stderr) ---"
    cat /var/log/cosmic-greeter-session.log 2>&1 || echo "(no session log yet)"
    echo ""

    echo "--- 12. svlogd current logs ---"
    echo "-- /var/log/cosmic-greeter/current --"
    cat /var/log/cosmic-greeter/current 2>&1 || echo "(empty)"
    echo "-- /var/log/cosmic-greeter-daemon/current --"
    cat /var/log/cosmic-greeter-daemon/current 2>&1 || echo "(empty)"
    echo ""

    echo "===== end diagnose ====="
} >> "$diag" 2>&1

chmod 0644 "$diag"
chmod -R a+rX /var/log/cosmic-greeter /var/log/cosmic-greeter-daemon 2>/dev/null || true

echo "Diagnostic written to: $diag"
echo "svlogd trees are now world-readable (a+rX)."
echo "Next: sudo reboot, wait for the grey screen, then re-run this script and"
echo "I will read the boot-time session log."