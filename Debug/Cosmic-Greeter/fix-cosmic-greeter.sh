#!/bin/bash
# fix-cosmic-greeter9.sh -- Vulkan experiment + greeter-stderr readout
# root-only. Run on the box with:
#     sudo bash ~/fix-cosmic-greeter9.sh              # capture + install vulkan if absent + restart + verify
#     sudo bash ~/fix-cosmic-greeter9.sh --check      # capture/report ONLY, no package install, no restart
# md5 (4 copies): run  md5sum  on all copies and confirm equal BEFORE running.
set -u

triage="/var/log/cosmic-greeter-triage9.txt"
check_only="no"
if [ "${1:-}" = "--check" ]; then check_only="yes"; fi

declare -a install_pkgs=("vulkan-loader" "mesa-vulkan-radeon" "vulkan-tools")
install_missing="no"

{
    echo "=== triage9 $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
    echo "--- intent ---"
    echo "triage8 proved seatd SERVES card0 to an ACTIVE client (no CLIENT_ACTIVE"
    echo "EPERM) and cosmic received a dup of seatd's master file (drm-client-id 51"
    echo "shared by seatd fd 18 and 4 cosmic fds). The CLIENT_ACTIVE gate lead is"
    echo "DEAD. The grey background + cursor DO scan out on a clean boot; only the"
    echo "iced/wgpu login panel fails to map, and this box has NO Vulkan at all"
    echo " (no libvulkan.so.1, no radv ICD; mesa-vulkan-radeon not installed, only"
    echo " the virtio stub ICD). So this probe (a) READ the greeter/compositor stderr"
    echo " that Beta-v2.9.11's svlogd log/run finally survives, (b) checks the"
    echo " Vulkan/GL stack, (c) installs the real Vulkan stack when missing,"
    echo " (d) restarts the greeter and re-reads the logs to see if the adapter/"
    echo " layer error is gone. DRM master is only revisited if the WARN +"
    echo " Permission-denied commits persist WITH Vulkan present."
    echo "mode: ${check_only}"
    echo ""
    echo "--- before: log trees readable ---"
    chmod -R a+rX /var/log/cosmic-greeter /var/log/cosmic-greeter-daemon 2>/dev/null || true
    chmod 0644 /var/log/cosmic-greeter-session.log 2>/dev/null || true
    chmod -R a+rX /var/log/seatd 2>/dev/null || true

    echo ""
    echo "--- 1. greeter/compositor stderr (svlogd current) — renderer lines ---"
    for f in /var/log/cosmic-greeter/current /var/log/cosmic-greeter-daemon/current; do
        echo "[$f]"
        if [ -f "$f" ]; then
            grep -aiE 'wgpu|iced|adapter|vulkan|egl|gl_|gl:|surface|renderer|render\b|error|panic|failed|unable|no suitable|no vulkan|libseat|drm' "$f" 2>/dev/null | tail -40 || echo "  (no matching lines)"
            echo "[raw tail 12:]"
            tail -n 12 "$f" 2>&1
        else
            echo "  (missing)"
        fi
    done

    echo ""
    echo "--- 2. Vulkan/GL stack present? ---"
    echo "[libvulkan:]"
    ls -l /usr/lib/libvulkan.so* 2>&1 || echo "  NO libvulkan present"
    echo "[ICD files:]"
    ls -l /usr/share/vulkan/icd.d/ 2>&1 || echo "  (no icd.d dir)"
    echo "[packages:]"
    xbps-query -l 2>/dev/null | grep -iE 'vulkan|mesa|glvnd' || echo "  (xbps-query: none)"
    echo "[vulkaninfo:]"
    if command -v vulkaninfo >/dev/null 2>&1; then
        vulkaninfo --summary 2>&1 | grep -iE 'deviceName|driverName|apiVersion|deviceType|GPU' | head -12 || echo "  (vulkaninfo ran but matched nothing)"
    else
        echo "  vulkan-tools NOT installed"
    fi
    echo "[cosmic env VK/EGL vars:]"
    cosmic_pid=$(pgrep -f 'cosmic-comp cosmic-greeter' | tail -1)
    if [ -n "${cosmic_pid:-}" ] && [ -r "/proc/$cosmic_pid/environ" ]; then
        tr '\0' '\n' < "/proc/$cosmic_pid/environ" | grep -iE 'VK_|EGL_|GALLIUM_|LIBGL_|VULKAN' || echo "  (no VK/EGL env vars seen)"
    else
        echo "  (no cosmic-comp pid or cannot read /proc/$cosmic_pid/environ)"
    fi

    echo ""
    echo "--- 3. DRM master / commit metrics BEFORE (session log) ---"
    sess=/var/log/cosmic-greeter-session.log
    sess_lines_before=0
    if [ -f "$sess" ]; then
        sess_lines_before=$(wc -l < "$sess" 2>/dev/null | tr -d ' ')
        echo "[session log line count: $sess_lines_before]"
        echo "[Unable to become drm master: $(grep -ac 'Unable to become drm master' "$sess" 2>/dev/null)]
[clear_state Permission denied: $(grep -ac 'clear_state.*Permission denied\|Permission denied (os error 13)' "$sess" 2>/dev/null)]
[libseat ENOTCONN panic: $(grep -ac 'ENOTCONN.*Transport endpoint is not connected' "$sess" 2>/dev/null)]"
        echo "[DRM client table now:]"
        cat /sys/kernel/debug/dri/0/clients 2>&1 || echo "  (debugfs not available)"
    else
        echo "  (no $sess)"
    fi

    echo ""
    echo "--- 4. decision ---"
    icd_count=$(ls /usr/share/vulkan/icd.d/*.json 2>/dev/null | wc -l | tr -d ' ')
    lib_count=$(ls /usr/lib/libvulkan.so* 2>/dev/null | wc -l | tr -d ' ')
    echo "[ICD json files: $icd_count]  [libvulkan files: $lib_count]"
    if [ "$icd_count" -ge 1 ] && [ "$lib_count" -ge 1 ]; then
        echo "  Vulkan loader + >=1 ICD already present -> no install"
    else
        echo "  Vulkan stack MISSING (icd=$icd_count lib=$lib_count)"
        install_missing="yes"
    fi
    echo ""

    if [ "$check_only" = "no" ] && [ "$install_missing" = "yes" ]; then
        echo "--- 5. install real Vulkan stack: ${install_pkgs[*]} ---"
        for missing_pkg in "${install_pkgs[@]}"; do
            if ! xbps-query "$missing_pkg" >/dev/null 2>&1; then
                echo "[will install] $missing_pkg (not currently installed)"
            else
                echo "[already installed] $missing_pkg"
            fi
        done
        echo "--- running xbps-install -Sy -y ... ---"
        xbps-install -Sy -y "${install_pkgs[@]}" 2>&1
        echo "[xbps-install exit: $?]"
        echo ""
        echo "--- post-install stack check ---"
        ls -l /usr/lib/libvulkan.so* 2>&1 || echo "  libvulkan: STILL MISSING"
        ls -l /usr/share/vulkan/icd.d/ 2>&1 || echo "  icd.d: STILL MISSING/empty"
        if command -v vulkaninfo >/dev/null 2>&1; then
            vulkaninfo --summary 2>&1 | grep -iE 'deviceName|driverName|apiVersion|deviceType' | head -8 || echo "  vulkaninfo matched nothing"
        fi
        echo ""
        echo "--- 6. restart the greeter stack (may pick up new ICDs) ---"
        sv restart cosmic-greeter-daemon cosmic-greeter 2>&1
        echo "waiting for cosmic-comp relaunch..."
        for i in $(seq 1 30); do
            pgrep -f 'cosmic-comp cosmic-greeter' >/dev/null 2>&1 && break
            sleep 1
        done
        if pgrep -f 'cosmic-comp cosmic-greeter' >/dev/null 2>&1; then
            echo "greeter relaunched; warming 12s for device-open/adapter init..."
            sleep 12
        else
            echo "WARNING: greeter did NOT relaunch (capture evidence anyway)" >&2
        fi
    elif [ "$check_only" = "yes" ]; then
        echo "--- 5-6. SKIPPED (--check: no install, no restart) ---"
    else
        echo "--- 5-6. SKIPPED (Vulkan stack already present; no restart without --force) ---"
    fi

    echo ""
    echo "--- 7. greeter/compositor stderr AFTER (renderer lines since restart) ---"
    for f in /var/log/cosmic-greeter/current /var/log/cosmic-greeter-daemon/current; do
        echo "[$f]"
        if [ -f "$f" ]; then
            grep -aiE 'wgpu|iced|adapter|vulkan|egl|surface|renderer|error|panic|failed|unable|no suitable|libseat|drm' "$f" 2>/dev/null | tail -30 || echo "  (no matching lines)"
            echo "[raw tail 12:]"
            tail -n 12 "$f" 2>&1
        else
            echo "  (missing)"
        fi
    done

    echo ""
    echo "--- 8. DRM master / commit metrics AFTER ---"
    if [ -f "$sess" ]; then
        sess_lines_after=$(wc -l < "$sess" 2>/dev/null | tr -d ' ')
        echo "[session log new lines since before: $((sess_lines_after - sess_lines_before))]"
        echo "[Unable to become drm master (total): $(grep -ac 'Unable to become drm master' "$sess" 2>/dev/null)]
[clear_state Permission denied (total): $(grep -ac 'clear_state.*Permission denied\|Permission denied (os error 13)' "$sess" 2>/dev/null)]
[libseat ENOTCONN panic (total): $(grep -ac 'ENOTCONN.*Transport endpoint is not connected' "$sess" 2>/dev/null)]"
        echo "[new session-log lines:]"
        if [ "$sess_lines_after" -gt "$sess_lines_before" ]; then
            tail -n +$((sess_lines_before + 1)) "$sess" 2>/dev/null | tail -n 30 || true
        else
            echo "  (no new lines — session log did not rotate/grow; check /var/log/cosmic-greeter/current)"
        fi
    fi
    echo ""
    echo "--- 9. DRM client table AFTER ---"
    cat /sys/kernel/debug/dri/0/clients 2>&1 || echo "  (debugfs not available)"
} 2>&1 | tee "$triage"
chmod 0644 "$triage"

echo ""
echo "================================================================"
echo "Triage written to:  $triage"
echo "HOW TO READ:"
echo "  Step 1/7 renderer lines: if the greeter app logged wgpu/Vulkan"
echo "     adapter failures and they are GONE in step 7 after the install,"
echo "     the missing Vulkan stack was the cause -> login panel should draw."
echo "  Step 8: if 'Unable to become drm master' + 'clear_state Permission"
echo "     denied' COUNTS CLIMB even with Vulkan present, DRM master is still"
echo "     the blocker -> revisit which fd DrmDeviceFd wraps (id-55 self-open"
echo "     vs id-51 seatd dup), do NOT re-open the CLIENT_ACTIVE gate."
echo "  The ENOTCONN dispatch panic at startup is a seatd open_seat race,"
echo "     tracked separately; ignore it unless rendering still fails."
echo "================================================================"