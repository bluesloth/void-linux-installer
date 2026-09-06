#!/bin/bash
# fix-cosmic-greeter8.sh -- seatd debug probe v2: KEEP exec 2>&1 so -l debug reaches svlogd
# root-only. Run: sudo bash ~/fix-cosmic-greeter8.sh
# md5 (4 copies): run  md5sum  on all copies and confirm equal BEFORE running.
set -u

triage="/var/log/cosmic-greeter-triage8.txt"
debugfs_clients="/sys/kernel/debug/dri/0/clients"
seatd_old_run="/etc/sv/seatd/run"
seatd_debug_run="/etc/sv/seatd/run.fix8-debug"
seatd_run_restored="no"

restore_seatd_run() {
    if [ "$seatd_run_restored" = "no" ]; then
        echo "[restore] restoring $seatd_old_run from $seatd_debug_run" | tee -a "$triage"
        if [ -f "$seatd_debug_run" ]; then
            cp -f "$seatd_debug_run" "$seatd_old_run"
            chmod 0755 "$seatd_old_run" 2>/dev/null || true
        else
            echo "[restore] WARNING: $seatd_debug_run missing; seatd run left in debug state!" | tee -a "$triage"
        fi
        seatd_run_restored="yes"
        sv restart seatd 2>&1 | tee -a "$triage"
    fi
}
trap restore_seatd_run EXIT

{
    echo "=== triage8 $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo "--- intent ---"
    echo "fix7 dropped 'exec 2>&1' from the debug run script, so seatd -l debug never"
    echo "reached svlogd (step 7 died at 'seatd stopped'). This probe keeps exec 2>&1"
    echo "and captures the seatd server's CLIENT_OPEN_DEVICE handling verbatim."

    echo ""
    echo "--- before: current seatd run script ---"
    cat "$seatd_old_run" 2>&1

    echo ""
    echo "--- step 1: enable seatd DEBUG loglevel (KEYS: exec 2>&1) ---"
    seatd_run_restored="no"
    cp -f "$seatd_old_run" "$seatd_debug_run" 2>/dev/null || true
    printf '#!/bin/sh\nexec 2>&1\nexec /usr/bin/seatd -g _seatd -l debug\n' > "$seatd_old_run"
    chmod 0755 "$seatd_old_run"
    cat "$seatd_old_run"
    # rotate log so we only see the debug run
    sv t 2>/dev/null || true
    sv restart seatd/log seatd 2>&1
    sleep 2
    sv status seatd 2>&1

    echo ""
    echo "--- step 2: restart the greeter stack (fresh libseat session) ---"
    sv restart cosmic-greeter-daemon cosmic-greeter 2>&1
    echo "waiting for cosmic-comp relaunch..."
    for i in $(seq 1 30); do
        pgrep -f 'cosmic-comp cosmic-greeter' >/dev/null 2>&1 && break
        sleep 1
    done
    if pgrep -f 'cosmic-comp cosmic-greeter' >/dev/null 2>&1; then
        echo "greeter relaunched; warming 12s for full device-open sequence..."
        sleep 12
    else
        echo "WARNING: greeter did NOT relaunch" >&2
    fi

    echo ""
    echo "--- step 3: identity snapshot (all cosmic-comp pids) ---"
    echo "seatd pid:   $(pgrep -x seatd | head -1)"
    echo "all cosmic-comp pids:"
    pgrep -af 'cosmic-comp' 2>/dev/null || echo "  (pgrep found none)"
    cosmic_pid=$(pgrep -f 'cosmic-comp cosmic-greeter' | tail -1)
    echo "(cosmic pid used below: $cosmic_pid)"

    echo ""
    echo "--- step 4: /proc fd inventory (card0 fds) ---"
    for label_pid in "seatd:$(pgrep -x seatd | head -1)" "cosmic:$cosmic_pid"; do
        label="${label_pid%%:*}"
        pid="${label_pid#*:}"
        echo ""
        echo "[$label pid=$pid]"
        if [ -n "$pid" ] && [ -d "/proc/$pid/fd" ]; then
            card0_fds=0
            render_fds=0
            for f in /proc/$pid/fd/*; do
                tgt=$(readlink "$f" 2>/dev/null) || continue
                fn=$(basename "$f")
                case "$tgt" in
                    /dev/dri/card*)
                        card0_fds=$((card0_fds + 1))
                        echo "  fd $fn -> $tgt"
                        echo "  --- fdinfo fd $fn ---"
                        cat "/proc/$pid/fdinfo/$fn" 2>&1 | grep -E 'pos|flags|ino|drm-driver|drm-client-id|drm-pdev|drm-memory|drm-engine|amd-' || echo "  (no fdinfo)"
                        ;;
                    /dev/dri/render*)
                        render_fds=$((render_fds + 1))
                        echo "  fd $fn -> $tgt (render node)"
                        ;;
                esac
            done
            echo "  TOTAL card0 fds: $card0_fds  render-nodes: $render_fds"
        else
            echo "  (no /proc/$pid/fd)"
        fi
    done

    echo ""
    echo "--- step 5: DRM clients table (card0) ---"
    cat "$debugfs_clients" 2>&1 || echo "(debugfs not available)"

    echo ""
    echo "--- step 6: LIBSEAT_BACKEND seen by cosmic-comp ---"
    if [ -n "${cosmic_pid:-}" ] && [ -r "/proc/$cosmic_pid/environ" ]; then
        tr '\0' '\n' < "/proc/$cosmic_pid/environ" | grep -iE 'LIBSEAT|SEATD|WAYLAND' || echo "  (no LIBSEAT/SEATD env vars seen)"
    else
        echo "  (cannot read /proc/$cosmic_pid/environ)"
    fi

    echo ""
    echo "--- step 7: seatd DEBUG daemon log (FULL, from new svlogd current) ---"
    echo "[svlogd files present:]"
    ls -la /var/log/seatd/ 2>&1 || echo "  (cannot list)"
    echo "[DEBUG log tail 150 lines:]"
    tail -n 150 /var/log/seatd/current 2>&1 || echo "  (no seatd log)"
    echo "[DEBUG log grep for device-open sequence:]"
    grep -iE 'Opening device|Could not open|client is not active|set master|drm master|dup|SERVER_DEVICE_OPENED|reused|New client|Opened client|Removed client|Activating' /var/log/seatd/current 2>&1 | tail -40 || echo "  (no matching lines)"

    echo ""
    echo "--- step 8: seatd socket peer PIDs (who is connected to seatd now) ---"
    ss -xap 2>&1 | grep -i seatd || echo "  (ss shows no seatd peer)"
    ls -l /proc/*/fd 2>/dev/null | grep '/run/seatd.sock' | sed -E 's#/proc/([0-9]+)/fd/[0-9]+#\1#' | sort -u | while read p; do echo "  pid $p has seatd.sock open: $(tr '\0' ' ' < /proc/$p/cmdline 2>/dev/null)"; done

    echo ""
    echo "--- step 9: greeter session log (FULL grep, not just tail) ---"
    echo "[smithay/optain/master/device lines in whole log:]"
    grep -aE 'smithay|optain|master|drm|Unable|FailedToOpenDevice|Failed to open device' /var/log/cosmic-greeter-session.log 2>&1 | tail -30 || echo "  (none)"
    echo "[seatd/libseat/seat lines in whole log:]"
    grep -aiE 'seatd|libseat|seat' /var/log/cosmic-greeter-session.log 2>&1 | tail -20 || echo "  (none)"
    echo "[last 15 raw lines of session log:]"
    tail -n 15 /var/log/cosmic-greeter-session.log 2>&1
} 2>&1 | tee -a "$triage"
chmod 0644 "$triage"

echo ""
echo "================================================================"
echo "Triage written to:  $triage"
echo "KEY: seatd DEBUG lines decide the story:"
echo "  'Opening device /dev/dri/card0 for client 1 on seat0' + master OK"
echo "     -> seatd served the dup; cosmic's OWN open is the anomaly"
echo "  'Could not open device: client is not active'"
echo "     -> CLIENT_ACTIVE gate blocks the serve; cosmic falls back"
echo "================================================================"