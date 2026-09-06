#!/bin/bash
# fix-cosmic-greeter7.sh -- seatd debug probe: where does cosmic-comp's card0 fd come from?
# root-only. Run: sudo bash ~/fix-cosmic-greeter7.sh
# md5 (4 copies): run  md5sum  on all copies and confirm equal BEFORE running.
set -u

triage="/var/log/cosmic-greeter-triage7.txt"
debugfs_clients="/sys/kernel/debug/dri/0/clients"
seatd_old_run="/etc/sv/seatd/run"
seatd_debug_run="/etc/sv/seatd/run.fix7-debug"
seatd_run_restored="no"

restore_seatd_run() {
    if [ "$seatd_run_restored" = "no" ]; then
        echo "[restore] restoring $seatd_old_run from $seatd_debug_run" | tee -a "$triage"
        if [ -f "$seatd_debug_run" ]; then
            cp -f "$seatd_debug_run" "$seatd_old_run"
            chmod 0755 "$seatd_old_run" 2>/dev/null || true
            echo "[restore] diff (old/new):" | tee -a "$triage"
            diff -u "$seatd_debug_run" "$seatd_old_run" >> "$triage" 2>&1 || true
        else
            echo "[restore] WARNING: $seatd_debug_run missing; seatd run left in debug state!" | tee -a "$triage"
        fi
        seatd_run_restored="yes"
        sv restart seatd 2>&1 | tee -a "$triage"
    fi
}
trap restore_seatd_run EXIT

{
    echo "=== triage7 $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo "--- intent ---"
    echo "Determine whether cosmic-comp's card0 drm fd is seatd's SCM_RIGHTS dup (same inode"
    echo "as seatd's, shares master id) or an independent open  (different inode, non-master)."

    echo ""
    echo "--- before: current seatd run script ---"
    cat "$seatd_old_run" 2>&1

    echo ""
    echo "--- step 1: enable seatd DEBUG loglevel ---"
    seatd_run_restored="no"
    cp -f "$seatd_old_run" "$seatd_debug_run" 2>/dev/null || true
    printf '#!/bin/sh\n[ -r /etc/default/seatd ] && . /etc/default/seatd\nexec /usr/bin/seatd -g _seatd -l debug ${SEATD_RUN_ARGS:-}\n' > "$seatd_old_run"
    chmod 0755 "$seatd_old_run"
    cat "$seatd_old_run"
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
        echo "greeter relaunched (pid $(pgrep -f 'cosmic-comp cosmic-greeter' | head -1)); warming 10s..."
        sleep 10
    else
        echo "WARNING: greeter did NOT relaunch" >&2
    fi

    echo ""
    echo "--- step 3: identity snapshot ---"
    seatd_pid=$(pgrep -x seatd | head -1)
    cosmic_pid=$(pgrep -f 'cosmic-comp cosmic-greeter' | head -1)
    echo "seatd pid:   ${seatd_pid:-<none>}"
    echo "cosmic pid:  ${cosmic_pid:-<none>}"

    echo ""
    echo "--- step 4: /proc fd inventory (card0 fds: count + fdinfo) ---"
    echo "(Note: /dev/dri/card0 is a char device; all opens show same devtmpfs inode."
    echo " Distinction comes from debugfs id column and /proc/PID/fdinfo/N.)"
    echo ""
    echo "fuser card0 (all PIDs holding /dev/dri/card0):"
    fuser -v /dev/dri/card0 2>&1 || echo "  (fuser unavailable or no holders)"
    echo ""
    for label_pid in "seatd:$seatd_pid" "cosmic:$cosmic_pid"; do
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
                        echo "    fdinfo:"
                        cat "/proc/$pid/fdinfo/$fn" 2>&1 | sed 's/^/      /' || echo "      (no fdinfo)"
                        ;;
                    /dev/dri/render*)
                        render_fds=$((render_fds + 1))
                        echo "  fd $fn -> $tgt"
                        ;;
                esac
            done
            echo "  TOTAL card0 fds: $card0_fds  render-nodes: $render_fds"
            if [ "$label" = "cosmic" ] && [ "$card0_fds" -gt 1 ]; then
                echo "  >>> cosmic-comp holds MULTIPLE card0 fds: libseat dup + independent open!"
            elif [ "$label" = "cosmic" ] && [ "$card0_fds" -eq 1 ]; then
                echo "  >>> cosmic-comp holds exactly 1 card0 fd (libseat dup OR independent open, not both)"
            fi
        else
            echo "  (no /proc/$pid/fd)"
        fi
    done

    echo ""
    echo "--- step 5: DRM clients table BEFORE master stress (card0) ---"
    cat "$debugfs_clients" 2>&1 || echo "(debugfs not available)"

    echo ""
    echo "--- step 6: LIBSEAT_BACKEND seen by cosmic-comp ---"
    if [ -n "${cosmic_pid:-}" ] && [ -r "/proc/$cosmic_pid/environ" ]; then
        tr '\0' '\n' < "/proc/$cosmic_pid/environ" | grep -iE 'LIBSEAT|SEATD|WAYLAND' || echo "  (no LIBSEAT/SEATD env vars seen)"
    else
        echo "  (cannot read /proc/$cosmic_pid/environ)"
    fi

    echo ""
    echo "--- step 7: seatd DEBUG daemon log tail (key lines: Opening device / Could not open device) ---"
    tail -n 120 /var/log/seatd/current 2>&1 | grep -iE 'device|open|master|client|seat|active|dup|fd' || tail -n 120 /var/log/seatd/current 2>&1

    echo ""
    echo "--- step 8: greeter session log tail (smithay WARN / optain / master) ---"
    tail -n 80 /var/log/cosmic-greeter-session.log 2>&1 | grep -iE 'smithay|optain|master|drm|error|warn|device' || tail -n 80 /var/log/cosmic-greeter-session.log 2>&1
} 2>&1 | tee -a "$triage"
chmod 0644 "$triage"

echo ""
echo "================================================================"
echo "Triage written to:  $triage"
echo "Key outputs:"
echo "  - seatd debug log: 'Opening device' reached server? CLIENT_ACTIVE gate?"
echo "  - /proc fd count: 1 = single path, 2 = dup + independent open"
echo "  - debugfs: seatd id-26 (master=y) vs cosmic id-30 (master=n) = two struct drm_files"
echo "================================================================"