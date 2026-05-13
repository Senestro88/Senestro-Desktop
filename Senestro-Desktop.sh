#!/data/data/com.termux/files/usr/bin/bash
#######################################################
#  🐧 SENESTRO LINUX DESKTOP — Proot Installer v2.6
#
#  Installs a full Ubuntu Linux + XFCE4 desktop
#  on Android via proot-distro, bridged through
#  Termux-X11 for display and PulseAudio for sound.
#
#  ─────────────────────────────────────────────────
#  WHAT GETS INSTALLED
#  ─────────────────────────────────────────────────
#  Termux side:
#    proot-distro, pulseaudio, termux-x11-nightly,
#    mesa-zink, virglrenderer, mesa-demos, xorg-xrandr
#
#  Ubuntu side:
#    XFCE4 + goodies, xfce4-terminal, thunar,
#    mousepad, Firefox ESR, VLC, VS Code (code),
#    Git, Nano, Neovim, Wget, cURL, mesa-utils
#
#  ─────────────────────────────────────────────────
#  FULL FEATURE LIST (v2.6)
#  ─────────────────────────────────────────────────
#  01. GPU acceleration auto-setup (Turnip/Zink/VirGL)
#      — device GPU family detected automatically;
#        Adreno → Turnip/Zink, other → VirGL/swrast
#
#  02. /sdcard shared with Ubuntu on every login
#      — --bind /sdcard:/sdcard passed to every
#        proot-distro call so Android storage is
#        always accessible at /sdcard inside Ubuntu
#
#  03. 90-second pkg-update timeout guard
#      — wraps "pkg update" in a 90s timeout so a
#        dead or unreachable repo URL cannot hang
#        the installer indefinitely
#
#  04. Skip-if-installed checks for every package
#      — both Termux (dpkg -s) and Ubuntu (dpkg-query)
#        are checked before each install; already-
#        present packages are skipped with a green tick
#
#  05. Full installation log — cleared on every run
#      — log is reset (truncated) at the start of
#        every run mode (install, fix-*, uninstall)
#        so the file always reflects the latest run
#
#  06. One-click launcher scripts
#      — start-senestro-desktop.sh  : full desktop launch
#      — stop-senestro-desktop.sh   : clean shutdown
#      — senestro-desktop-shell.sh  : drop into Ubuntu bash
#      — senestro-switch-shell.sh   : switch login shell
#      — senestro-desktop-gpu.sh    : GPU test inside Ubuntu
#
#  07. chsh PAM bypass shim
#      — /usr/local/bin/chsh intercepts all chsh calls
#        and edits /etc/passwd directly — no PAM,
#        no password; --help and -l forwarded to real binary
#
#  08. Default shell picker during setup
#      — detected shells (bash/fish/zsh/dash) offered
#        as a numbered menu; choice written to /etc/passwd
#
#  09. Optional new Ubuntu user with passwordless sudo
#      — username validated (lowercase, no spaces),
#        existence inside Ubuntu checked before creating;
#        added to sudo group with NOPASSWD sudoers entry
#
#  10. VLC root-launch bypass
#      — binary patch: geteuid→getppid in ELF string table
#        (reversible via apt reinstall vlc)
#      — start-vlc wrapper sets DISPLAY and --vout x11
#
#  11. fish PATH fix (/usr/local/bin in fish PATH)
#      — /etc/fish/conf.d/senestro-path.fish ensures
#        start-vlc, chsh shim, and switch-shell are found
#        without a full path when fish is the login shell
#
#  12. VS Code as a native XFCE desktop app
#      — installed via packages.microsoft.com/repos/code
#        with a signed Microsoft GPG key; launches with
#        --no-sandbox and a proot-safe user-data dir
#
#  13. D-Bus machine-id auto-repair
#      — generated on every desktop launch if missing or
#        malformed; written to /etc/machine-id and
#        /var/lib/dbus/machine-id to prevent dbus errors
#
#  14. Standalone repair flags
#      — --fix-vlc       : reinstall VLC + patch + wrapper
#      — --fix-firefox   : reinstall Firefox ESR
#      — --fix-code-oss  : reinstall VS Code via Microsoft repo
#      — --fix-all       : run all three repairs in sequence
#
#  15. Full uninstall with per-item prompts
#      — --uninstall removes: Ubuntu rootfs, proot-distro
#        download cache, proot-distro config/rootfs leftovers,
#        GPU config file (~/.config/senestro-desktop-config.sh),
#        and the Senestro-Desktop launcher directory;
#        each item is confirmed separately before deletion
#
#  16. Self-update (--update)
#      — downloads latest script from SCRIPT_UPDATE_URL,
#        runs bash -n syntax check on the download,
#        backs up the current version, replaces in-place;
#        curl with wget fallback; 90s timeout guard
#
#  17. Changelog viewer (--changelog)
#      — displays the full version history extracted
#        directly from this script's own header — no
#        network connection required
#
#  18. Installation status checker (--status)
#      — reports which Termux packages, Ubuntu proot,
#        launcher scripts, and config files are present;
#        useful for verifying a partial or past install
#
#  19. Internet connectivity + disk space pre-checks
#      — verified at the start of every install run;
#        warns if free space is < 2 GB and aborts if
#        no internet is reachable before downloading
#
#  ─────────────────────────────────────────────────
#  VERSION HISTORY  [CHANGELOG_START]
#  ─────────────────────────────────────────────────
#  v2.1 — chsh PAM bypass + VLC root fix + optional user
#  v2.2 — fish PATH fix via /etc/fish/conf.d
#  v2.5 — VS Code via Microsoft apt repo; removed Chromium;
#          --fix-code-oss flag; --fix-all flag; --uninstall flag
#  v2.6 — Config file removed during uninstall; 19-item
#          feature list; log cleared on every run; detailed
#          comments throughout; --update / --version / --help /
#          --changelog / --status flags; internet + disk
#          pre-checks; banner version corrected; bug fixes
#  [CHANGELOG_END]
#
#  Author: Senestro
#######################################################


# =============================================================================
# CONFIGURATION
#
# BASE_DIR   — all generated launcher scripts live here
# LOG_DIR    — log directory inside BASE_DIR
# LOG_FILE   — single log file; truncated at the start of every run
# DISTRO     — proot-distro distribution name
# PREFIX     — Termux usr prefix (used for sanity checks where needed)
# =============================================================================
TOTAL_STEPS=10
CURRENT_STEP=0
BASE_DIR="$HOME/Senestro-Desktop"
LOG_DIR="$BASE_DIR/logs"
LOG_FILE="$LOG_DIR/senestro-desktop.log"
DISTRO="ubuntu"
PREFIX="/data/data/com.termux/files/usr"


# =============================================================================
# ANSI COLOR CODES
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
PURPLE='\033[0;35m'
NC='\033[0m'  # reset / no color


# =============================================================================
# LOGGING
#
# Appends a timestamped line to LOG_FILE.
# The log file itself is truncated (reset) at the start of every run mode
# so the file always reflects only the most recent execution — not an
# ever-growing history from previous runs.
# =============================================================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}


# =============================================================================
# PROGRESS BAR
#
# Called once per major step (STEP 1–10).
# Increments CURRENT_STEP, computes the completion percentage, and draws a
# 20-character block-character bar with green fill and gray empty segments.
# =============================================================================
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    FILLED=$((PERCENT / 5))
    EMPTY=$((20 - FILLED))

    # Build the filled (green) and empty (gray) segments of the progress bar
    BAR="${GREEN}"
    for ((i=0; i<FILLED; i++)); do BAR+="█"; done
    BAR+="${GRAY}"
    for ((i=0; i<EMPTY; i++)); do BAR+="░"; done
    BAR+="${NC}"

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}


# =============================================================================
# SPINNER
#
# Prints a waiting indicator next to a message while a background process runs,
# then shows ✓ or ✗ when it finishes.
#
# Why dots instead of \r (carriage return):
#   \r is unreliable in Termux — it creates a new line rather than overwriting
#   the current one, flooding the terminal with repeated copies of the same
#   message. Printing a dot per second avoids that problem entirely.
#
# Usage:
#   (some_long_command) &
#   spinner $! "Doing the thing"
# =============================================================================
spinner() {
    local pid=$1
    local message=$2

    printf "  ${YELLOW}⏳${NC} %s" "$message"

    # Poll the background process until it exits
    while kill -0 "$pid" 2>/dev/null; do
        printf "${CYAN}.${NC}"
        sleep 1
    done

    wait "$pid"
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf " ${GREEN}✓${NC}\n"
    else
        printf " ${RED}✗${NC} ${RED}(failed — see $LOG_FILE)${NC}\n"
    fi

    return $exit_code
}


# =============================================================================
# INTERNET CONNECTIVITY CHECK
#
# Attempts a fast HEAD request (or ping fallback) to a reliable host.
# Called at the start of every install run before any downloads begin.
# Exits with an error message if no internet is reachable so the user
# knows immediately rather than getting obscure download failures later.
#
# Probes (tried in order, first success wins):
#   1. curl HEAD to https://packages.termux.dev  (the Termux repo itself)
#   2. curl HEAD to https://google.com           (broad fallback)
#   3. ping -c 1 8.8.8.8                         (ICMP fallback, no curl)
# =============================================================================
check_internet() {
    printf "  ${YELLOW}⏳${NC} Checking internet connectivity..."

    local _OK=0

    # Try curl first (available in Termux by default)
    if command -v curl > /dev/null 2>&1; then
        if curl -fsS --head --connect-timeout 8 \
               "https://packages.termux.dev" > /dev/null 2>&1 || \
           curl -fsS --head --connect-timeout 8 \
               "https://google.com" > /dev/null 2>&1; then
            _OK=1
        fi
    fi

    # Ping fallback — works even if curl is missing
    if [ $_OK -eq 0 ] && command -v ping > /dev/null 2>&1; then
        if ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1; then
            _OK=1
        fi
    fi

    if [ $_OK -eq 1 ]; then
        printf " ${GREEN}✓${NC}\n"
        log "OK    internet connectivity check passed"
        return 0
    else
        printf " ${RED}✗${NC}\n"
        echo ""
        echo -e "  ${RED}✗  No internet connection detected.${NC}"
        echo -e "  ${YELLOW}Make sure Wi-Fi or mobile data is enabled, then try again.${NC}"
        echo ""
        log "FAIL  internet connectivity check failed — aborting"
        exit 1
    fi
}


# =============================================================================
# DISK SPACE CHECK
#
# Reads the available space on the filesystem that contains $HOME.
# Warns if free space is below 2 GB (Ubuntu rootfs ~500 MB + packages).
# Aborts if free space is below 500 MB (install would almost certainly fail).
#
# Uses df -k (POSIX-compatible) so the output is in 1K blocks, then
# converts to MB for a human-readable warning message.
# =============================================================================
check_disk_space() {
    printf "  ${YELLOW}⏳${NC} Checking available disk space..."

    local _AVAIL_KB
    _AVAIL_KB=$(df -k "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')

    # If df fails for any reason, skip the check and continue
    if [ -z "$_AVAIL_KB" ] || ! [[ "$_AVAIL_KB" =~ ^[0-9]+$ ]]; then
        printf " ${YELLOW}⚠ (unable to check)${NC}\n"
        log "WARN  disk space check skipped — df output unparseable"
        return 0
    fi

    local _AVAIL_MB=$(( _AVAIL_KB / 1024 ))
    local _AVAIL_GB_INT=$(( _AVAIL_MB / 1024 ))
    local _AVAIL_GB_DEC=$(( (_AVAIL_MB % 1024) * 10 / 1024 ))

    printf " ${WHITE}${_AVAIL_GB_INT}.${_AVAIL_GB_DEC} GB free${NC}"

    if [ $_AVAIL_MB -lt 500 ]; then
        # Below 500 MB — abort: install cannot succeed
        printf " ${RED}✗${NC}\n"
        echo ""
        echo -e "  ${RED}✗  Critically low disk space (${_AVAIL_GB_INT}.${_AVAIL_GB_DEC} GB free).${NC}"
        echo -e "  ${YELLOW}At least 500 MB is required. Free up space and try again.${NC}"
        echo ""
        log "FAIL  disk space check: only ${_AVAIL_MB} MB free — aborting"
        exit 1
    elif [ $_AVAIL_MB -lt 2048 ]; then
        # Below 2 GB — warn and let the user decide
        printf " ${YELLOW}⚠${NC}\n"
        echo ""
        echo -e "  ${YELLOW}⚠  Low disk space (${_AVAIL_GB_INT}.${_AVAIL_GB_DEC} GB free).${NC}"
        echo -e "  ${YELLOW}   2 GB or more is recommended. The install may run out of space.${NC}"
        echo ""
        log "WARN  disk space check: ${_AVAIL_MB} MB free (below 2 GB recommended)"
    else
        printf " ${GREEN}✓${NC}\n"
        log "OK    disk space check: ${_AVAIL_MB} MB free"
    fi
}


# =============================================================================
# TERMUX PACKAGE HELPERS
# =============================================================================

# -----------------------------------------------------------------------------
# pkg_update_safe [label]
#
# Runs "pkg update" with a 90-second timeout so a dead or unreachable
# repository URL cannot hang the installer indefinitely.
# Exit code 124 means the command timed out; a warning is logged but
# execution continues so the caller decides whether to abort.
# -----------------------------------------------------------------------------
pkg_update_safe() {
    local label=${1:-"Refreshing package lists"}
    log "pkg update (${label})"

    (timeout 90 bash -c \
        'DEBIAN_FRONTEND=noninteractive yes | pkg update -y' \
        >> "$LOG_FILE" 2>&1) &
    spinner $! "${label}..."

    local rc=$?
    [ $rc -eq 124 ] && log "WARN  pkg update timed out after 90s (${label})"
    return $rc
}

# -----------------------------------------------------------------------------
# is_pkg_installed <package>
#
# Returns 0 (true) if the Termux package is already installed according
# to dpkg, non-zero otherwise.
# -----------------------------------------------------------------------------
is_pkg_installed() {
    dpkg -s "$1" > /dev/null 2>&1
}

# -----------------------------------------------------------------------------
# install_pkg <package> [display-name]
#
# Installs a single Termux package using "pkg install".
# Skips silently if the package is already present.
# Logs the outcome (SKIP / OK / FAIL) with exit code on failure.
# -----------------------------------------------------------------------------
install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}

    if is_pkg_installed "$pkg"; then
        printf "  ${GREEN}✓${NC} %s — already installed, skipping\n" "$name"
        log "SKIP  $pkg ($name) — already installed"
        return 0
    fi

    log "START $pkg ($name)"
    (DEBIAN_FRONTEND=noninteractive yes | pkg install "$pkg" -y >> "$LOG_FILE" 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "  ${GREEN}✓${NC} %s — installed\n" "$name"
        log "OK    $pkg ($name)"
    else
        printf "  ${RED}✗${NC} %s ${RED}(failed — check $LOG_FILE)${NC}\n" "$name"
        log "FAIL  $pkg ($name) — exit code $exit_code"
    fi

    return $exit_code
}


# =============================================================================
# UBUNTU (PROOT) PACKAGE HELPERS
#
# Every proot-distro call includes:
#   --shared-tmp          → shares Termux's /tmp so the X11 socket created
#                           by termux-x11 is visible inside Ubuntu
#   --bind /sdcard:/sdcard → mounts Android storage at /sdcard inside Ubuntu
# =============================================================================

# -----------------------------------------------------------------------------
# run_in_ubuntu <command>
#
# Runs a shell command inside the Ubuntu proot container.
# All output (stdout + stderr) goes to LOG_FILE only — nothing is shown
# on screen. Use run_in_ubuntu_spin when you want a visible spinner.
# -----------------------------------------------------------------------------
run_in_ubuntu() {
    proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- \
        bash -c "$1" >> "$LOG_FILE" 2>&1
}

# -----------------------------------------------------------------------------
# run_in_ubuntu_spin <command> <message>
#
# Runs a command inside the Ubuntu proot container with a live spinner
# printed to the terminal. Output still goes to LOG_FILE only.
# Returns the exit code of the proot command.
# -----------------------------------------------------------------------------
run_in_ubuntu_spin() {
    local cmd=$1
    local msg=$2

    (proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- \
        bash -c "$cmd" >> "$LOG_FILE" 2>&1) &
    spinner $! "$msg"
    return $?
}

# -----------------------------------------------------------------------------
# is_apt_installed_inside_ubuntu <package>
#
# Returns 0 (true) if the apt package is installed inside the Ubuntu proot
# container, non-zero otherwise.
# -----------------------------------------------------------------------------
is_apt_installed_inside_ubuntu() {
    proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- \
        dpkg -s "$1" > /dev/null 2>&1
}

# -----------------------------------------------------------------------------
# install_apt_inside_ubuntu <package> [display-name]
#
# Installs an apt package inside the Ubuntu proot container.
# Skips silently if the package is already installed (checked via dpkg-query).
# Uses a spinner while the installation runs in the background.
# Logs SKIP / OK / FAIL with exit code.
# -----------------------------------------------------------------------------
install_apt_inside_ubuntu() {
    local pkg=$1
    local name=${2:-$pkg}

    if is_apt_installed_inside_ubuntu "$pkg"; then
        printf "  ${GREEN}✓${NC} %-35s already installed — skipped\n" "$name"
        log "SKIP  (apt) $pkg"
        return 0
    fi

    log "START (apt) $pkg"
    (proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- bash -c \
        "DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $pkg" \
        >> "$LOG_FILE" 2>&1) &
    spinner $! "Installing ${name} [Ubuntu]..."

    local rc=$?
    log "$( [ $rc -eq 0 ] && echo 'OK   ' || echo 'FAIL ' ) (apt) $pkg — exit $rc"
    return $rc
}


# =============================================================================
# BANNER
#
# Clears the screen and prints the Senestro Desktop ASCII art header.
# Called once at the start of the main install flow.
# =============================================================================
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔══════════════════════════════════════════════╗
    ║                                              ║
    ║   🐧  SENESTRO LINUX DESKTOP v2.6  🐧        ║
    ║       Full Ubuntu + XFCE4 on Android         ║
    ║           GPU Accelerated · /sdcard Shared   ║
    ║                                              ║
    ╚══════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
}


# =============================================================================
# DEVICE DETECTION
#
# Runs before the counted installation steps.
# Reads Android system properties to detect the device model, Android version,
# CPU ABI, and GPU vendor.
#
# GPU detection logic:
#   - If ro.hardware.egl contains "adreno" → Qualcomm GPU → use Turnip/Zink
#   - If the brand matches major Qualcomm OEMs → also assume Adreno/Turnip
#   - Otherwise → fall back to VirGL with software (swrast) rendering
#
# The GPU_DRIVER variable set here is used by step_termux_pkgs() to pick the
# correct virglrenderer package.
# =============================================================================
detect_device() {
    echo -e "${PURPLE}[*] Detecting your device...${NC}"
    echo ""

    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    CPU_ABI=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a")
    GPU_VENDOR=$(getprop ro.hardware.egl 2>/dev/null || echo "")

    echo -e "  ${GREEN}📱${NC} Device:  ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  ${GREEN}🤖${NC} Android: ${WHITE}${ANDROID_VERSION}${NC}"
    echo -e "  ${GREEN}⚙️${NC}  CPU:     ${WHITE}${CPU_ABI}${NC}"

    # Detect Qualcomm Adreno GPU — enables the Turnip/Zink hardware path.
    # Brand matching catches devices where ro.hardware.egl is not set by OEM.
    if [[ "$GPU_VENDOR" == *"adreno"* ]] || \
       [[ "$DEVICE_BRAND" =~ ^([Ss]amsung|[Oo]ne[Pp]lus|[Xx]iaomi|[Pp]oco|[Rr]ealme|[Oo]ppo|[Vv]ivo)$ ]]; then
        GPU_DRIVER="freedreno"
        echo -e "  ${GREEN}🎮${NC} GPU:     ${WHITE}Adreno (Qualcomm) — Turnip/Zink driver${NC}"
    else
        GPU_DRIVER="swrast"
        echo -e "  ${GREEN}🎮${NC} GPU:     ${WHITE}Non-Adreno — VirGL/software rendering${NC}"
    fi

    log "Device: $DEVICE_BRAND $DEVICE_MODEL | Android $ANDROID_VERSION | ABI $CPU_ABI | GPU driver: $GPU_DRIVER"
    echo ""
    sleep 1
}


# =============================================================================
# STEP 1 — UPDATE TERMUX
#
# Updates the Termux package index and upgrades all installed packages.
# pkg_update_safe wraps the update in a 90-second timeout guard.
# =============================================================================
step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating Termux packages...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Termux system update ==="

    pkg_update_safe "Updating package lists"

    (DEBIAN_FRONTEND=noninteractive yes | pkg upgrade -y >> "$LOG_FILE" 2>&1) &
    spinner $! "Upgrading installed packages..."
}


# =============================================================================
# STEP 2 — ADD PACKAGE REPOSITORIES
#
# x11-repo — provides termux-x11-nightly (the X11 display server)
# tur-repo  — provides mesa-zink and virglrenderer-mesa-zink (GPU drivers)
#
# IMPORTANT: pkg update MUST run after each new repo package so the package
# index for that repo is fetched before we try to install from it.
# Without the refresh, mesa-zink and virglrenderer will not be found.
# =============================================================================
step_repos() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Adding package repositories...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Repositories ==="

    # x11-repo: must be added before installing termux-x11-nightly
    install_pkg "x11-repo" "X11 Repository"
    pkg_update_safe "Refreshing package lists (x11-repo)"

    # tur-repo: must be added before installing mesa-zink / virglrenderer-mesa-zink
    install_pkg "tur-repo" "TUR Repository"
    # CRITICAL: second refresh required — without it mesa-zink is not found
    pkg_update_safe "Refreshing package lists (tur-repo)"
}


# =============================================================================
# STEP 3 — INSTALL TERMUX-SIDE PACKAGES (including GPU drivers)
#
# GPU driver selection (set by detect_device):
#   GPU_DRIVER == "freedreno" → virglrenderer-mesa-zink (Adreno/Turnip path)
#   GPU_DRIVER == "swrast"    → virglrenderer-android  (Android GLES fallback)
#
# NOTE: Do NOT install the bare "mesa" package — it conflicts with mesa-zink.
#   mesa-zink provides the same OpenGL stack but routed over Vulkan (Zink).
# =============================================================================
step_termux_pkgs() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Termux packages & GPU drivers...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Termux packages + GPU ==="

    install_pkg "proot-distro"       "Proot Distro"
    install_pkg "pulseaudio"         "PulseAudio"
    install_pkg "termux-x11-nightly" "Termux-X11 Display Server"
    install_pkg "xorg-xrandr"        "XRandR (Display Settings)"
    install_pkg "mesa-zink"          "Mesa Zink (OpenGL over Vulkan)"

    # Install the GPU-family-appropriate VirGL renderer
    if [ "$GPU_DRIVER" == "freedreno" ]; then
        install_pkg "virglrenderer-mesa-zink" "VirGL Renderer (Zink/Adreno)"
    else
        install_pkg "virglrenderer-android"   "VirGL Renderer (Android GLES)"
    fi

    install_pkg "mesa-demos" "Mesa Demos (glxinfo / glxgears)"

    echo -e "  ${GREEN}✓${NC} GPU acceleration configured (driver path: ${WHITE}${GPU_DRIVER}${NC})"
    log "GPU step complete (driver path: $GPU_DRIVER)"
}


# =============================================================================
# STEP 4 — INSTALL UBUNTU VIA PROOT-DISTRO
#
# Uses "proot-distro login ubuntu -- true" as the installed check because it
# is version-agnostic (the rootfs path changed in proot-distro v4+).
# A secondary grep on the proot-distro output catches the "already installed"
# message as a safety net if the login test fails for other reasons.
#
# Downloads ~200 MB rootfs on first install — informs the user upfront.
# Exits the whole installer on failure (Ubuntu is a hard dependency).
# =============================================================================
step_install_ubuntu() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Ubuntu (proot)...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Ubuntu proot-distro install ==="

    # Fast path: if proot-distro can log into Ubuntu, it is already installed
    if proot-distro login "$DISTRO" -- true > /dev/null 2>&1; then
        printf "  ${GREEN}✓${NC} Ubuntu — already installed and working, skipping\n"
        log "SKIP  ubuntu (proot-distro login test passed)"
        return 0
    fi

    echo -e "  ${YELLOW}ℹ${NC}  Downloading Ubuntu rootfs (~200 MB). This may take a few minutes..."
    log "START proot-distro install $DISTRO"

    local install_out
    install_out=$(proot-distro install "$DISTRO" 2>&1)
    local rc=$?
    echo "$install_out" >> "$LOG_FILE"

    # Secondary check: proot-distro sometimes prints "already installed" and
    # exits 0 or non-zero — treat either as success
    if echo "$install_out" | grep -qi "already installed"; then
        printf "  ${GREEN}✓${NC} Ubuntu — already installed (detected from proot-distro output)\n"
        log "OK    ubuntu (already installed — treated as success)"
        return 0
    fi

    if [ $rc -eq 0 ]; then
        printf "  ${GREEN}✓${NC} Ubuntu rootfs installed successfully\n"
        log "OK    ubuntu proot install"
        return 0
    fi

    # Hard failure: cannot continue without Ubuntu
    printf "  ${RED}✗${NC} Ubuntu install failed (exit $rc) — check $LOG_FILE\n"
    printf "  ${YELLOW}ℹ${NC}  Try manually: proot-distro install ubuntu\n"
    printf "  ${YELLOW}ℹ${NC}  If already present: proot-distro reset ubuntu\n"
    log "FAIL  ubuntu proot install — exit $rc"
    exit 1
}


# =============================================================================
# USER SETUP (not a counted step — interactive dialog)
#
# Runs after Ubuntu is installed but before apt updates.
# Handles three sub-tasks:
#   1. Root password — set via chpasswd inside Ubuntu
#   2. Default shell  — chosen from a menu, written to /etc/passwd via sed
#                       (bypasses PAM which is broken inside proot)
#   3. Optional user  — created with passwordless sudo; existence check
#                       avoids duplicate-user errors on re-runs
#
# PASSWORD SAFETY NOTE:
#   Passwords are passed via echo/pipe to chpasswd.
#   Avoid " (double-quote) and $ (dollar sign) in passwords — those
#   characters can cause unexpected shell expansion.
# =============================================================================
step_user_setup() {
    echo ""
    echo -e "${PURPLE}[*] Ubuntu User Setup${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log "=== USER SETUP: root password + shell + optional new user ==="

    # ── 1. Root password ─────────────────────────────────────────────────────
    echo -e "  ${CYAN}Set a password for the Ubuntu root account.${NC}"
    echo ""
    while true; do
        printf "  Root password        : "
        read -rs ROOT_PASS
        echo ""
        printf "  Confirm root password: "
        read -rs ROOT_PASS2
        echo ""

        if [ -z "$ROOT_PASS" ]; then
            printf "  ${RED}✗${NC} Password cannot be empty. Try again.\n\n"
        elif [ "$ROOT_PASS" != "$ROOT_PASS2" ]; then
            printf "  ${RED}✗${NC} Passwords do not match. Try again.\n\n"
        else
            break
        fi
    done

    run_in_ubuntu "echo \"root:${ROOT_PASS}\" | chpasswd"
    printf "  ${GREEN}✓${NC} Root password set\n"
    log "OK    root password set"
    # Clear password variables from memory immediately after use
    unset ROOT_PASS ROOT_PASS2

    echo ""

    # ── 2. Default shell picker ───────────────────────────────────────────────
    # chsh calls PAM which always fails in proot ("PAM: Authentication failure").
    # The chsh shim installed in step 9 edits /etc/passwd directly.
    # At this point the shim is not yet installed, so we do the same thing
    # ourselves — write directly to /etc/passwd via sed.
    echo -e "  ${CYAN}Choose the default login shell for root.${NC}"
    echo -e "  ${GRAY}(chsh PAM shim will be installed — chsh -s and switch-shell work natively)${NC}"
    echo ""

    # Candidate shells to probe inside Ubuntu
    _SHELL_CANDIDATES=("/bin/bash" "/usr/bin/fish" "/bin/zsh" "/usr/bin/zsh" "/bin/dash")
    _SHELL_LABELS=("Bash (recommended)" "Fish" "Zsh" "Zsh (alt)" "Dash")
    _AVAIL_PATHS=()
    _AVAIL_LABELS=()

    # Build a list of shells that actually exist and are executable inside Ubuntu
    for _si in "${!_SHELL_CANDIDATES[@]}"; do
        _sp="${_SHELL_CANDIDATES[$_si]}"
        _sl="${_SHELL_LABELS[$_si]}"
        _exists=$(proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- \
            bash -c "test -x '${_sp}' && echo yes || echo no" 2>/dev/null)
        if [[ "$_exists" == *"yes"* ]]; then
            _AVAIL_PATHS+=("$_sp")
            _AVAIL_LABELS+=("$_sl")
        fi
    done

    if [ ${#_AVAIL_PATHS[@]} -eq 0 ]; then
        # No shells detected yet (Ubuntu just installed, no extras present)
        printf "  ${YELLOW}⚠${NC}  No shells detected yet — defaulting to /bin/bash\n"
        _CHOSEN_SHELL="/bin/bash"
        _CHOSEN_LABEL="Bash"
    else
        # Print numbered menu; mark /bin/bash as default
        for _si in "${!_AVAIL_PATHS[@]}"; do
            if [ "${_AVAIL_PATHS[$_si]}" = "/bin/bash" ]; then
                echo -e "    ${GREEN}[$((${_si}+1))]${NC} ${_AVAIL_LABELS[$_si]}  ${GRAY}→  ${_AVAIL_PATHS[$_si]}  ← default${NC}"
            else
                echo -e "    ${CYAN}[$((${_si}+1))]${NC} ${_AVAIL_LABELS[$_si]}  ${GRAY}→  ${_AVAIL_PATHS[$_si]}${NC}"
            fi
        done
        echo ""
        echo -e "  ${GRAY}Press Enter to keep Bash, or type a number to choose another.${NC}"
        printf "  Choose [default: 1 — Bash]: "
        read -r _SHELL_CHOICE

        # Default to 1 (bash) on empty input or non-numeric input
        if [[ -z "$_SHELL_CHOICE" ]] || ! [[ "$_SHELL_CHOICE" =~ ^[1-9][0-9]*$ ]]; then
            _SHELL_CHOICE=1
        fi
        _IDX=$((_SHELL_CHOICE - 1))
        # Clamp to valid range
        if [ "$_IDX" -lt 0 ] || [ "$_IDX" -ge "${#_AVAIL_PATHS[@]}" ]; then
            printf "  ${YELLOW}⚠${NC}  Invalid choice — defaulting to Bash.\n"
            _IDX=0
        fi
        _CHOSEN_SHELL="${_AVAIL_PATHS[$_IDX]}"
        _CHOSEN_LABEL="${_AVAIL_LABELS[$_IDX]}"
    fi

    # Write the chosen shell directly into /etc/passwd — bypasses PAM entirely
    run_in_ubuntu \
        "sed -i 's|^\(root:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\).*|\1${_CHOSEN_SHELL}|' /etc/passwd"
    printf "  ${GREEN}✓${NC} Root default shell set to: ${WHITE}${_CHOSEN_LABEL}${NC} (${_CHOSEN_SHELL})\n"
    log "OK    root shell set to ${_CHOSEN_SHELL} via /etc/passwd"

    # Clean up all shell-picker temporary variables
    unset _SHELL_CANDIDATES _SHELL_LABELS _AVAIL_PATHS _AVAIL_LABELS
    unset _si _sp _sl _exists _SHELL_CHOICE _IDX _CHOSEN_SHELL _CHOSEN_LABEL

    echo ""

    # ── 3. Optional new user ──────────────────────────────────────────────────
    echo -e "  ${CYAN}Would you like to create a new Ubuntu user?${NC}"
    printf "  [y/N]: "
    read -r CREATE_USER
    echo ""

    if [[ "$CREATE_USER" =~ ^[Yy]$ ]]; then

        # Username validation loop: lowercase, no spaces, existence check
        while true; do
            echo -e "  ${GRAY}ℹ  Must be lowercase letters, digits, hyphen or underscore (e.g. john)${NC}"
            printf "  Enter username: "
            read -r NEW_USER

            if [ -z "$NEW_USER" ]; then
                printf "  ${RED}✗${NC} Username cannot be empty. Try again.\n\n"
                continue
            elif ! echo "$NEW_USER" | grep -qE '^[a-z][a-z0-9_-]*$'; then
                printf "  ${RED}✗${NC} Invalid — use lowercase only, no spaces or uppercase.\n\n"
                continue
            fi

            # Check whether the user already exists inside Ubuntu
            _USER_EXISTS=$(proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- \
                bash -c "getent passwd '${NEW_USER}' > /dev/null 2>&1 && echo yes || echo no" 2>/dev/null)

            if [[ "$_USER_EXISTS" == *"yes"* ]]; then
                echo ""
                printf "  ${YELLOW}⚠${NC}  User ${WHITE}${NEW_USER}${NC} already exists inside Ubuntu.\n"
                echo ""
                echo -e "  ${CYAN}What would you like to do?${NC}"
                echo -e "    ${GREEN}[1]${NC} Continue without creating a new user"
                echo -e "    ${CYAN}[2]${NC} Enter a different username"
                echo ""
                printf "  Choose [1/2]: "
                read -r _EXIST_CHOICE
                echo ""

                if [[ "$_EXIST_CHOICE" == "1" ]]; then
                    printf "  ${GRAY}Skipping user creation — ${NEW_USER} already exists.${NC}\n"
                    log "INFO  user '${NEW_USER}' already exists — creation skipped by user choice"
                    unset NEW_USER _USER_EXISTS _EXIST_CHOICE
                    CREATE_USER="skip_exists"
                    break
                else
                    printf "  ${GRAY}OK — enter a different username.${NC}\n\n"
                    unset NEW_USER _USER_EXISTS _EXIST_CHOICE
                    continue
                fi
            fi

            unset _USER_EXISTS
            break
        done

        echo ""

        # Only create the user if we didn't bail out due to an existing account
        if [[ "$CREATE_USER" != "skip_exists" ]]; then

            # User password input loop — must match and be non-empty
            while true; do
                printf "  Password for ${WHITE}${NEW_USER}${NC}: "
                read -rs NEW_PASS
                echo ""
                printf "  Confirm password    : "
                read -rs NEW_PASS2
                echo ""

                if [ -z "$NEW_PASS" ]; then
                    printf "  ${RED}✗${NC} Password cannot be empty. Try again.\n\n"
                elif [ "$NEW_PASS" != "$NEW_PASS2" ]; then
                    printf "  ${RED}✗${NC} Passwords do not match. Try again.\n\n"
                else
                    break
                fi
            done

            # Create the user inside Ubuntu with bash as default shell,
            # set their password, add to sudo group, grant NOPASSWD sudo
            run_in_ubuntu "
                useradd -m -s /bin/bash '${NEW_USER}'
                echo \"${NEW_USER}:${NEW_PASS}\" | chpasswd
                usermod -aG sudo '${NEW_USER}'
                mkdir -p /etc/sudoers.d
                echo '${NEW_USER} ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/${NEW_USER}
                chmod 440 /etc/sudoers.d/${NEW_USER}
            "
            printf "  ${GREEN}✓${NC} User ${WHITE}${NEW_USER}${NC} created with default shell /bin/bash\n"
            printf "  ${GREEN}✓${NC} Added to sudo group with passwordless login\n"
            log "OK    user '${NEW_USER}' created with passwordless sudo"

            # Clear password variables from memory immediately after use
            unset NEW_PASS NEW_PASS2

        fi  # end skip_exists gate

    else
        echo -e "  ${GRAY}Skipping — you can add users later with: useradd -m -s /bin/bash <name>${NC}"
        log "INFO  new user creation skipped"
    fi

    unset CREATE_USER NEW_USER
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}


# =============================================================================
# STEP 5 — UPDATE UBUNTU PACKAGES
#
# Runs apt-get update and apt-get upgrade inside Ubuntu to ensure all
# packages are up to date before installing new software.
# software-properties-common is installed explicitly because some Ubuntu
# 22.04 images omit it, and it is needed by add-apt-repository.
# =============================================================================
step_ubuntu_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating Ubuntu packages...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Ubuntu apt update/upgrade ==="

    run_in_ubuntu_spin "apt-get update -y" \
        "apt update [Ubuntu]..."

    run_in_ubuntu_spin \
        "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends" \
        "apt upgrade [Ubuntu]..."

    run_in_ubuntu_spin \
        "DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common" \
        "Installing apt tools [Ubuntu]..."
}


# =============================================================================
# STEP 6 — INSTALL XFCE4 DESKTOP INSIDE UBUNTU
#
# xfce4-goodies  — panel plugins, task manager, screensaver, extras
# xfce4-terminal — terminal emulator used by the desktop shortcut
# thunar         — file manager (explicit install for desktop shortcut)
# mousepad       — lightweight text editor that integrates well with XFCE
# =============================================================================
step_ubuntu_desktop() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing XFCE4 Desktop [Ubuntu]...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: XFCE4 desktop ==="

    install_apt_inside_ubuntu "xfce4"          "XFCE4 Desktop Environment"
    install_apt_inside_ubuntu "xfce4-goodies"  "XFCE4 Goodies (plugins & extras)"
    install_apt_inside_ubuntu "xfce4-terminal" "XFCE4 Terminal Emulator"
    install_apt_inside_ubuntu "thunar"         "Thunar File Manager"
    install_apt_inside_ubuntu "mousepad"       "Mousepad Text Editor"
}


# =============================================================================
# STEP 7 — INSTALL APPLICATIONS INSIDE UBUNTU
#
# firefox-esr:
#   Ubuntu 22.04+ ships Firefox as a snap stub — snaps do not work in proot
#   (no snapd). firefox-esr is a real .deb and works perfectly.
#
# VS Code ("code"):
#   The Ubuntu/Debian package name is "code" (not "code-oss" — that is the
#   Arch Linux package). Installed via packages.microsoft.com/repos/code with
#   a signed Microsoft GPG key. See install_vscode_inside_ubuntu() for details.
#
# mesa-utils:
#   Provides glxinfo and glxgears for GPU verification inside Ubuntu.
# =============================================================================

# -----------------------------------------------------------------------------
# install_vscode_inside_ubuntu
#
# Adds the Microsoft apt repository and GPG key (idempotent — skips if files
# already exist), updates only the VS Code source, then installs "code".
# Uses a custom spinner loop because the multi-step setup would time out a
# normal spinner() call on slow connections.
# -----------------------------------------------------------------------------
install_vscode_inside_ubuntu() {
    printf "  ${YELLOW}⏳${NC} Installing VS Code [Ubuntu]..."
    log "START (vscode) code"

    # Check if VS Code is already installed via dpkg-query
    local _already
    _already=$(proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- \
        bash -c "dpkg-query -W -f='\${Status}' code 2>/dev/null || true" 2>/dev/null || true)
    if echo "$_already" | grep -q "install ok installed"; then
        printf " ${GREEN}✓ (already installed)${NC}\n"
        log "SKIP  (vscode) code — already installed"
        return 0
    fi

    local _rc=0
    (proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- \
        bash -c '
            set -e
            export DEBIAN_FRONTEND=noninteractive

            # Add Microsoft GPG key if not already present
            if [ ! -f /usr/share/keyrings/microsoft.gpg ]; then
                curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
                    | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
            fi

            # Add the VS Code apt source list if not already present
            if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
                ARCH=$(dpkg --print-architecture)
                echo "deb [arch=${ARCH} signed-by=/usr/share/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
                    > /etc/apt/sources.list.d/vscode.list
            fi

            # Update only the VS Code source to avoid a full apt-get update
            apt-get update \
                -o Dir::Etc::sourcelist="sources.list.d/vscode.list" \
                -o Dir::Etc::sourceparts="-" \
                -o APT::Get::List-Cleanup="0" -y

            apt-get install -y --no-install-recommends code

            # Refresh the XFCE icon cache so the VS Code icon appears
            gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
        ' >> "$LOG_FILE" 2>&1) &
    local _pid=$!

    # Custom spinner: print a dot every 2 seconds (install can take 1–3 min)
    while kill -0 "$_pid" 2>/dev/null; do
        printf "${CYAN}.${NC}"
        sleep 2
    done
    wait "$_pid"
    _rc=$?

    if [ $_rc -eq 0 ]; then
        printf " ${GREEN}✓${NC}\n"
        log "OK    (vscode) code — installed"
    else
        printf " ${RED}✗ (failed — see $LOG_FILE)${NC}\n"
        log "FAIL  (vscode) code — exit $_rc"
    fi
    return $_rc
}

step_ubuntu_apps() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Applications [Ubuntu]...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Ubuntu apps ==="

    install_apt_inside_ubuntu "mesa-utils"  "Mesa Utils (glxgears / glxinfo)"
    install_apt_inside_ubuntu "firefox-esr" "Firefox ESR"
    install_apt_inside_ubuntu "vlc"         "VLC Media Player"
    install_apt_inside_ubuntu "git"         "Git"
    install_apt_inside_ubuntu "nano"        "Nano Editor"
    install_apt_inside_ubuntu "neovim"      "Neovim"
    install_apt_inside_ubuntu "wget"        "Wget"
    install_apt_inside_ubuntu "curl"        "cURL"
    install_vscode_inside_ubuntu
}


# =============================================================================
# STEP 8 — CONFIGURE AUDIO BRIDGE, DISPLAY, AND DESKTOP SHORTCUTS
#
# PulseAudio runs on the Termux side; Ubuntu reaches it over TCP via
# PULSE_SERVER=127.0.0.1. The variable is written to /etc/environment so
# every Ubuntu session picks it up automatically without any manual export.
#
# GPU config file:
#   $HOME/.config/senestro-desktop-config.sh is written here and sourced by
#   start-senestro-desktop.sh before launching virgl_test_server. Keeping it
#   outside BASE_DIR makes it persist across full uninstalls if the user only
#   wipes the launcher directory and not the config.
#
# Desktop shortcuts:
#   Written to /root/Desktop inside Ubuntu so they appear on the XFCE desktop
#   immediately after the first login — no manual setup needed.
# =============================================================================
step_configure() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Configuring audio, display & shortcuts...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Audio config + display picker + shortcuts ==="

    # ── Display number picker ─────────────────────────────────────────────────
    echo -e "  ${CYAN}Which X11 display should the desktop use?${NC}"
    echo ""
    # Show which display numbers are currently in use (have a lock file)
    for d in 0 1 2 3 4 5; do
        if [ -f "/tmp/.X${d}-lock" ]; then
            echo -e "    :${d}  ${YELLOW}<- already in use${NC}"
        else
            echo -e "    :${d}  ${GREEN}<- free${NC}"
        fi
    done
    echo ""
    printf "  Enter display number [default: 1]: "
    read -r DISP_INPUT

    # Strip a leading colon if the user typed ":1" instead of "1"
    DISP_INPUT="${DISP_INPUT#:}"
    if [[ "$DISP_INPUT" =~ ^[0-9]$ ]]; then
        SENESTRO_DISPLAY=":${DISP_INPUT}"
    else
        SENESTRO_DISPLAY=":1"
    fi
    echo ""
    echo -e "  ${GREEN}✓${NC} Display set to ${WHITE}${SENESTRO_DISPLAY}${NC}"
    log "INFO  chosen display: $SENESTRO_DISPLAY"
    export SENESTRO_DISPLAY

    # ── GPU config file (Termux side) ─────────────────────────────────────────
    # Sourced by the start script before launching virgl_test_server.
    # Exporting these variables ensures mesa and virgl pick up the Zink path.
    mkdir -p "$HOME/.config"
    cat > "$HOME/.config/senestro-desktop-config.sh" << 'GPUEOF'
# Senestro Desktop — GPU Acceleration Config
# Sourced by start-senestro-desktop.sh before launching virgl_test_server.
# Enables the Zink (OpenGL-over-Vulkan) rendering path via Mesa environment variables.
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.3COMPAT
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
GPUEOF
    echo -e "  ${GREEN}✓${NC} GPU config written to $HOME/.config/senestro-desktop-config.sh"
    log "OK    GPU config file written"

    # ── PulseAudio TCP bridge in Ubuntu /etc/environment ─────────────────────
    # Written only if not already present — safe to re-run
    run_in_ubuntu \
        "grep -q 'PULSE_SERVER' /etc/environment 2>/dev/null || \
         echo 'PULSE_SERVER=127.0.0.1' >> /etc/environment"
    printf "  ${GREEN}✓${NC} PulseAudio bridge configured (PULSE_SERVER=127.0.0.1)\n"
    log "OK    audio config"

    # ── Desktop shortcuts inside Ubuntu ──────────────────────────────────────
    # Create the VS Code user-data directory before writing the .desktop file
    run_in_ubuntu "mkdir -p /root/Desktop/User/.vscode"

    # Firefox ESR shortcut
    run_in_ubuntu "printf '%s\n' \
        '[Desktop Entry]' \
        'Name=Firefox ESR' \
        'Comment=Web Browser' \
        'Exec=firefox-esr' \
        'Icon=firefox-esr' \
        'Type=Application' \
        'Categories=Network;WebBrowser;' \
        > /root/Desktop/Firefox.desktop"

    # XFCE Terminal shortcut
    run_in_ubuntu "printf '%s\n' \
        '[Desktop Entry]' \
        'Name=Terminal' \
        'Comment=XFCE Terminal' \
        'Exec=xfce4-terminal' \
        'Icon=xfce4-terminal' \
        'Type=Application' \
        'Categories=System;TerminalEmulator;' \
        > /root/Desktop/Terminal.desktop"

    # Thunar file manager shortcut
    run_in_ubuntu "printf '%s\n' \
        '[Desktop Entry]' \
        'Name=Files' \
        'Comment=File Manager' \
        'Exec=thunar' \
        'Icon=thunar' \
        'Type=Application' \
        'Categories=System;FileManager;' \
        > /root/Desktop/Files.desktop"

    # Mousepad text editor shortcut
    run_in_ubuntu "printf '%s\n' \
        '[Desktop Entry]' \
        'Name=Text Editor' \
        'Comment=Mousepad Text Editor' \
        'Exec=mousepad' \
        'Icon=accessories-text-editor' \
        'Type=Application' \
        'Categories=Utility;TextEditor;' \
        > /root/Desktop/TextEditor.desktop"

    # VS Code shortcut — --no-sandbox required for proot (no user namespaces);
    # --user-data-dir points to a proot-safe location inside the Ubuntu rootfs
    run_in_ubuntu "printf '%s\n' \
        '[Desktop Entry]' \
        'Name=VS Code' \
        'Comment=Code Editor' \
        'Exec=code --no-sandbox --user-data-dir=/root/Desktop/User/.vscode' \
        'Icon=code' \
        'Type=Application' \
        'Categories=Development;' \
        > /root/Desktop/VSCode.desktop"

    # VLC shortcut — uses the start-vlc wrapper (installed in step 9)
    run_in_ubuntu "printf '%s\n' \
        '[Desktop Entry]' \
        'Name=VLC Media Player' \
        'Comment=Play media files' \
        'Exec=start-vlc' \
        'Icon=vlc' \
        'Type=Application' \
        'Categories=AudioVideo;Player;' \
        > /root/Desktop/VLC.desktop"

    # Make all desktop entries executable (required by some XFCE versions)
    run_in_ubuntu "chmod +x /root/Desktop/*.desktop 2>/dev/null"

    printf "  ${GREEN}✓${NC} Desktop shortcuts created (Firefox, VS Code, VLC, Terminal, Files, Text Editor)\n"
    log "OK    desktop shortcuts"
}


# =============================================================================
# STEP 9 — INSTALL PROOT HELPERS (shell utilities & VLC fix)
#
# Three small utilities installed inside Ubuntu to work around proot limits:
#
#   chsh (/usr/local/bin — shadows /usr/bin/chsh)
#     The real chsh calls PAM for authentication which always fails inside proot.
#     This drop-in shim is installed earlier on PATH and intercepts every
#     chsh call — from the user, scripts, or tools — editing /etc/passwd
#     directly via sed instead. --help and -l are forwarded to the real binary.
#
#   switch-shell (/usr/local/bin)
#     A friendlier numbered-menu wrapper that uses the same /etc/passwd sed
#     approach. Useful for interactive shell switching without remembering
#     full shell paths.
#
#   start-vlc (/usr/local/bin)
#     VLC refuses to start as root. Inside proot the user is always root and
#     cannot change that. The VLC binary is patched once at install time
#     (geteuid → getppid in the ELF string table) so the root guard never
#     triggers. start-vlc sets DISPLAY and forces --vout x11.
#
#   fish PATH config (/etc/fish/conf.d/senestro-path.fish)
#     Adds /usr/local/bin to fish's PATH via conf.d so start-vlc, chsh, and
#     switch-shell are all found without a full path when fish is the default.
# =============================================================================
step_proot_helpers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing proot helpers (shell/VLC)...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Proot helpers ==="

    # Capture the chosen display for baking into the start-vlc wrapper
    _DH="${SENESTRO_DISPLAY:-:1}"

    # ── chsh PAM bypass shim ──────────────────────────────────────────────────
    # Installed at /usr/local/bin/chsh — earlier on PATH than /usr/bin/chsh.
    # Every chsh invocation (user, script, installer) hits this shim first.
    run_in_ubuntu "cat > /usr/local/bin/chsh << 'CHSHEOF'
#!/bin/bash
# chsh — PAM-free drop-in for proot environments
# Installed at /usr/local/bin/chsh (ahead of /usr/bin/chsh on PATH).
# Edits /etc/passwd directly via sed — no PAM, no password required.
#
# Usage:
#   chsh -s /bin/fish          set root shell
#   chsh -s /bin/bash          revert to bash
#   chsh -s /bin/zsh username  set another user's shell
#   chsh                       interactive prompt
#   chsh --help / chsh -l      forwarded to real /usr/bin/chsh

_REAL_CHSH=/usr/bin/chsh

# Forward read-only flags to the real binary (no PAM needed for these)
for _a in \"\$@\"; do
    case \"\$_a\" in
        --help|-h|--list-shells|-l)
            exec \"\$_REAL_CHSH\" \"\$@\"
            ;;
    esac
done

_NEW_SHELL=\"\"
_TARGET_USER=\"root\"

# Parse arguments: chsh [-s SHELL] [USER]
while [ \$# -gt 0 ]; do
    case \"\$1\" in
        -s|--shell)
            _NEW_SHELL=\"\$2\"
            shift 2
            ;;
        -s*)
            _NEW_SHELL=\"\${1#-s}\"
            shift
            ;;
        --shell=*)
            _NEW_SHELL=\"\${1#--shell=}\"
            shift
            ;;
        -*)
            echo \"chsh: unknown option: \$1\" >&2
            exit 1
            ;;
        *)
            _TARGET_USER=\"\$1\"
            shift
            ;;
    esac
done

# Interactive mode — prompt when no -s argument was given
if [ -z \"\$_NEW_SHELL\" ]; then
    _CURRENT=\$(grep \"^\${_TARGET_USER}:\" /etc/passwd | cut -d: -f7)
    printf \"Changing the login shell for %s\n\" \"\$_TARGET_USER\"
    printf \"Enter the new value, or press ENTER for the default\n\"
    printf \"\tLogin Shell [%s]: \" \"\${_CURRENT:-/bin/bash}\"
    read -r _NEW_SHELL
    [ -z \"\$_NEW_SHELL\" ] && _NEW_SHELL=\"\${_CURRENT:-/bin/bash}\"
fi

# Validate: the shell binary must exist and be executable
if [ ! -f \"\$_NEW_SHELL\" ]; then
    echo \"chsh: \$_NEW_SHELL: does not exist\" >&2
    exit 1
fi
if [ ! -x \"\$_NEW_SHELL\" ]; then
    echo \"chsh: \$_NEW_SHELL: not executable\" >&2
    exit 1
fi

# Apply: edit /etc/passwd directly — no PAM involved
if grep -q \"^\${_TARGET_USER}:\" /etc/passwd; then
    sed -i \"s|^\(\${_TARGET_USER}:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\).*|\1\${_NEW_SHELL}|\" /etc/passwd
    echo \"Shell changed.\"
else
    echo \"chsh: user '\$_TARGET_USER' does not exist\" >&2
    exit 1
fi
CHSHEOF
chmod +x /usr/local/bin/chsh"

    printf "  ${GREEN}✓${NC} chsh PAM blocker installed (/usr/local/bin/chsh)\n"
    log "OK    chsh PAM blocker installed"

    # ── switch-shell ──────────────────────────────────────────────────────────
    run_in_ubuntu "cat > /usr/local/bin/switch-shell << 'SWITCHEOF'
#!/bin/bash
# switch-shell — change the login shell for root without chsh/PAM
#
# Usage:
#   switch-shell                   interactive numbered menu
#   switch-shell bash              switch directly to bash
#   switch-shell fish              switch directly to fish
#   switch-shell zsh               switch directly to zsh

_AVAIL=()
for _s in /bin/bash /usr/bin/fish /bin/zsh /usr/bin/zsh /bin/dash /bin/sh; do
    [ -x \"\$_s\" ] && _AVAIL+=(\"\$_s\")
done

if [ \${#_AVAIL[@]} -eq 0 ]; then
    echo 'No shells found in standard paths.'
    exit 1
fi

if [ -n \"\$1\" ]; then
    # Direct mode: match by binary name or full path
    _TARGET=''
    for _s in \"\${_AVAIL[@]}\"; do
        if [ \"\$(basename \"\$_s\")\" = \"\$1\" ] || [ \"\$_s\" = \"\$1\" ]; then
            _TARGET=\"\$_s\"
            break
        fi
    done
    if [ -z \"\$_TARGET\" ]; then
        echo \"Shell '\$1' not found. Install it first: apt install \$1\"
        exit 1
    fi
else
    # Interactive mode: numbered menu
    echo ''
    echo 'Available shells:'
    echo ''
    _CURRENT=\$(grep '^root:' /etc/passwd | cut -d: -f7)
    for _i in \"\${!_AVAIL[@]}\"; do
        _MARK=''
        [ \"\${_AVAIL[\$_i]}\" = \"\$_CURRENT\" ] && _MARK=' <- current'
        printf '  [%s] %s%s\n' \"\$((_i+1))\" \"\${_AVAIL[\$_i]}\" \"\$_MARK\"
    done
    echo ''
    printf '  Choose [1-%s]: ' \"\${#_AVAIL[@]}\"
    read -r _CHOICE
    _IDX=\$((_CHOICE - 1))
    if ! [[ \"\$_CHOICE\" =~ ^[1-9][0-9]*\$ ]] || \\
       [ \"\$_IDX\" -lt 0 ] || [ \"\$_IDX\" -ge \"\${#_AVAIL[@]}\" ]; then
        echo 'Invalid choice.'
        exit 1
    fi
    _TARGET=\"\${_AVAIL[\$_IDX]}\"
fi

# Write the chosen shell to /etc/passwd — same method as the chsh shim
sed -i \"s|^\(root:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\).*|\1\${_TARGET}|\" /etc/passwd
echo \"Default shell changed to: \${_TARGET}\"
echo 'Re-enter the Ubuntu shell for the change to take effect.'
SWITCHEOF
chmod +x /usr/local/bin/switch-shell"

    printf "  ${GREEN}✓${NC} switch-shell installed (/usr/local/bin/switch-shell)\n"
    log "OK    switch-shell helper installed"

    # ── start-vlc + VLC binary patch ──────────────────────────────────────────
    # VLC_SKIP_ROOT_CHECK was silently removed from VLC source and no longer
    # works in any Ubuntu apt version. The only reliable fix is a one-time
    # binary patch: replace "geteuid" with "getppid" in the ELF string table
    # so VLC calls getppid() (always > 0) instead of geteuid() (returns 0 for
    # root), preventing the root guard from triggering.
    # Reversible: apt reinstall vlc
    run_in_ubuntu "
        # Apply the binary patch only if geteuid is still present in the binary
        if strings /usr/bin/vlc 2>/dev/null | grep -q 'geteuid'; then
            sed -i 's/geteuid/getppid/' /usr/bin/vlc
        fi

        # Write the start-vlc launcher wrapper
        cat > /usr/local/bin/start-vlc << VLCEOF
#!/bin/bash
# start-vlc — launch VLC as root in proot
# /usr/bin/vlc is patched (geteuid→getppid) at install time so the
# root guard never triggers. --vout x11 forces the X11 video output;
# without it VLC auto-detects GL/Wayland outputs that break inside proot.
export DISPLAY=${_DH}
exec vlc --vout x11 \"\\\$@\"
VLCEOF
        chmod +x /usr/local/bin/start-vlc
    "

    printf "  ${GREEN}✓${NC} start-vlc installed — VLC binary patched (geteuid→getppid)\n"
    log "OK    start-vlc helper installed (VLC binary patched)"

    # ── fish PATH fix ─────────────────────────────────────────────────────────
    # /usr/local/bin is not on fish's default PATH. Without this, start-vlc,
    # the chsh shim, and switch-shell require a full path when fish is the
    # default shell — confusing for users expecting them to just work.
    run_in_ubuntu "mkdir -p /etc/fish/conf.d
cat > /etc/fish/conf.d/senestro-path.fish << 'FISHPATHEOF'
# Senestro Desktop — add /usr/local/bin to fish PATH
# Ensures start-vlc, chsh (shim), and switch-shell are found without
# a full path when fish is the default login shell.
fish_add_path /usr/local/bin
FISHPATHEOF"

    printf "  ${GREEN}✓${NC} fish PATH configured (/etc/fish/conf.d/senestro-path.fish)\n"
    log "OK    fish PATH configured with /usr/local/bin"

    log "OK    proot helpers step complete"
}


# =============================================================================
# STEP 10 — CREATE TERMUX-SIDE LAUNCHER SCRIPTS
#
# Generated scripts live in BASE_DIR ($HOME/Senestro-Desktop/):
#
#   start-senestro-desktop.sh — full desktop launch sequence:
#     1. Source GPU config
#     2. Kill stale sessions and remove X lock files
#     3. Fix D-Bus machine-id if missing or malformed
#     4. Start PulseAudio with TCP module
#     5. Start VirGL server (Termux side — before X11)
#     6. Start Termux-X11
#     7. Launch XFCE4 inside Ubuntu via proot-distro
#
#   stop-senestro-desktop.sh   — pkill all desktop-related processes
#   senestro-desktop-shell.sh  — enter Ubuntu bash shell
#   senestro-switch-shell.sh   — Termux-side wrapper for switch-shell
#   senestro-desktop-gpu.sh    — GPU test (glxinfo + glxgears) inside Ubuntu
#
# NOTE: The chosen display number is baked into the scripts as a literal via
#   sed after the heredoc, replacing __D__ with the actual digit.
#   This avoids quoting issues in the heredoc body.
# =============================================================================
step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating launcher scripts...${NC}"
    echo ""
    log "=== STEP $CURRENT_STEP: Launchers ==="

    # Extract the display number digit (strip the leading colon)
    _D="${SENESTRO_DISPLAY#:}"
    : "${_D:=1}"

    mkdir -p "$BASE_DIR"

    # ── start-senestro-desktop.sh ─────────────────────────────────────────────
    # Quoted heredoc prevents variable expansion during write;
    # __D__ is substituted by sed after writing so the display number
    # is baked in as a literal integer.
    cat > "$BASE_DIR/start-senestro-desktop.sh" << 'LAUNCHEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Senestro Linux Desktop — Startup Script (v2.6)
# Open the Termux-X11 app on your phone first, then run this script.

echo ""
echo "Starting Senestro Linux Desktop (Ubuntu + XFCE4)..."
echo ""

# ── Load GPU environment variables ───────────────────────────────────────────
# Sets GALLIUM_DRIVER=zink and Mesa version overrides for hardware acceleration
source "$HOME/.config/senestro-desktop-config.sh" 2>/dev/null

# ── Kill stale sessions from any previous run ─────────────────────────────────
echo "Cleaning up old sessions..."
pkill -f "com.termux.x11" 2>/dev/null
pkill -f "xfce4-session"  2>/dev/null
pkill -f "xfwm4"          2>/dev/null
pkill -f "xfce4-panel"    2>/dev/null
pkill -f "pulseaudio"     2>/dev/null
pkill -f "virgl_test"     2>/dev/null
sleep 2

# Remove stale X lock and socket files that prevent X11 from binding display :__D__
rm -f /tmp/.X__D__-lock
rm -f /tmp/.X11-unix/X__D__
rmdir /tmp/.X11-unix 2>/dev/null

# ── D-Bus machine-id repair ───────────────────────────────────────────────────
# dbus requires a valid 32-hex-character machine-id. proot resets /etc between
# runs and it can go missing or become malformed. Generate a fresh one if needed.
ROOTFS_MACHINEID="$(proot-distro login ubuntu -- cat /etc/machine-id 2>/dev/null)"
if [ -z "$ROOTFS_MACHINEID" ] || [ ${#ROOTFS_MACHINEID} -ne 32 ]; then
    echo "Generating D-Bus machine-id..."
    NEW_UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-')"
    [ -z "$NEW_UUID" ] && NEW_UUID="$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    proot-distro login ubuntu -- bash -c \
        "echo '$NEW_UUID' > /etc/machine-id
         mkdir -p /var/lib/dbus
         echo '$NEW_UUID' > /var/lib/dbus/machine-id"
fi

# ── PulseAudio audio server ───────────────────────────────────────────────────
echo "Starting PulseAudio..."
unset PULSE_SERVER
pulseaudio --kill 2>/dev/null
sleep 0.5
pulseaudio --start --exit-idle-time=-1
sleep 1
# Load TCP module so Ubuntu can reach PulseAudio over loopback (127.0.0.1)
pactl load-module module-native-protocol-tcp \
    auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null
export PULSE_SERVER=127.0.0.1

# ── VirGL GPU bridge (Termux side — must start before X11) ───────────────────
# virgl_test_server (Zink path) takes priority over virgl_test_server_android
if command -v virgl_test_server > /dev/null 2>&1; then
    echo "Starting VirGL (Zink)..."
    MESA_NO_ERROR=1 MESA_GL_VERSION_OVERRIDE=4.3COMPAT \
    MESA_GLES_VERSION_OVERRIDE=3.2 GALLIUM_DRIVER=zink \
    ZINK_DESCRIPTORS=lazy \
    virgl_test_server --use-egl-surfaceless --use-gles &
    sleep 1
elif command -v virgl_test_server_android > /dev/null 2>&1; then
    echo "Starting VirGL (Android GLES)..."
    virgl_test_server_android &
    sleep 1
fi

# ── Termux-X11 display server ─────────────────────────────────────────────────
echo "Starting X11 on :__D__ ..."
termux-x11 :__D__ -ac &
sleep 3

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Switch to Termux-X11 app to see the desktop!"
echo "  Display : :__D__"
echo "  Audio   : PulseAudio (127.0.0.1)"
echo "  Storage : /sdcard → shared inside Ubuntu"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Launch XFCE4 inside Ubuntu proot ─────────────────────────────────────────
# --shared-tmp          : X11 socket visible inside the container
# --bind /sdcard:/sdcard : Android storage accessible at /sdcard inside Ubuntu
# dbus-launch           : required for XFCE4 session and D-Bus services
proot-distro login ubuntu \
    --shared-tmp \
    --bind /sdcard:/sdcard \
    -- env \
    DISPLAY=:__D__ \
    PULSE_SERVER=127.0.0.1 \
    XDG_RUNTIME_DIR=/tmp/runtime-root \
    bash -c \
    "mkdir -p /tmp/runtime-root && \
     chmod 700 /tmp/runtime-root && \
     dbus-launch --exit-with-session startxfce4"
LAUNCHEOF

    # Bake the chosen display number into the script by replacing __D__ literal
    sed -i "s/__D__/${_D}/g" "$BASE_DIR/start-senestro-desktop.sh"
    chmod +x "$BASE_DIR/start-senestro-desktop.sh"
    printf "  ${GREEN}✓${NC} Created $BASE_DIR/start-senestro-desktop.sh (display :${_D})\n"

    # ── stop-senestro-desktop.sh ──────────────────────────────────────────────
    cat > "$BASE_DIR/stop-senestro-desktop.sh" << 'STOPEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Senestro Linux Desktop — Stop Script
# Kills all desktop-related processes in order: X11, audio, compositor, panel, GPU bridge
echo "Stopping Senestro Linux Desktop..."
pkill -f "com.termux.x11" 2>/dev/null
pkill -f "pulseaudio"     2>/dev/null
pkill -f "xfce4-session"  2>/dev/null
pkill -f "xfwm4"          2>/dev/null
pkill -f "xfce4-panel"    2>/dev/null
pkill -f "virgl_test"     2>/dev/null
echo "Desktop stopped."
STOPEOF
    chmod +x "$BASE_DIR/stop-senestro-desktop.sh"
    printf "  ${GREEN}✓${NC} Created $BASE_DIR/stop-senestro-desktop.sh\n"

    # ── senestro-desktop-shell.sh ─────────────────────────────────────────────
    # Drops into an Ubuntu bash shell with /sdcard and /tmp shared.
    cat > "$BASE_DIR/senestro-desktop-shell.sh" << 'SHELLEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Senestro Linux Desktop — Ubuntu Shell
# Enters the Ubuntu proot container with /sdcard and shared /tmp available.
echo "Entering Ubuntu shell... (type 'exit' to return to Termux)"
echo "Your Android storage is available at /sdcard"
echo ""
proot-distro login ubuntu --shared-tmp --bind /sdcard:/sdcard
SHELLEOF
    chmod +x "$BASE_DIR/senestro-desktop-shell.sh"
    printf "  ${GREEN}✓${NC} Created $BASE_DIR/senestro-desktop-shell.sh\n"

    # ── senestro-switch-shell.sh ──────────────────────────────────────────────
    # Termux-side entry point for the switch-shell utility installed inside Ubuntu.
    # Cannot be called directly from Termux because the binary is linked against
    # Ubuntu's glibc. This wrapper enters Ubuntu via proot-distro and forwards
    # the argument (shell name or empty for interactive menu) to switch-shell.
    cat > "$BASE_DIR/senestro-switch-shell.sh" << 'SWSHEOF'
#!/data/data/com.termux/files/usr/bin/bash
#######################################################
#  senestro-switch-shell.sh
#  Change the default login shell inside Ubuntu proot.
#
#  Usage (from Termux):
#    bash senestro-switch-shell.sh          — interactive menu
#    bash senestro-switch-shell.sh bash     — switch to bash
#    bash senestro-switch-shell.sh fish     — switch to fish
#    bash senestro-switch-shell.sh zsh      — switch to zsh
#
#  Why this script exists:
#    chsh uses PAM authentication which does not work in proot.
#    The switch-shell utility inside Ubuntu edits /etc/passwd
#    directly via sed — no password or PAM required.
#    This wrapper enters Ubuntu via proot-distro and delegates.
#######################################################

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🐚  Senestro Switch-Shell"
echo "  Changes the default login shell inside Ubuntu proot"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Delegate to switch-shell inside Ubuntu; forward $1 if provided
if [ -n "$1" ]; then
    echo "  Switching shell to: $1"
    echo ""
    proot-distro login ubuntu --shared-tmp --bind /sdcard:/sdcard -- \
        bash /usr/local/bin/switch-shell "$1"
else
    echo "  No shell specified — opening interactive menu..."
    echo ""
    proot-distro login ubuntu --shared-tmp --bind /sdcard:/sdcard -- \
        bash /usr/local/bin/switch-shell
fi

echo ""
echo "  Done. Re-enter the Ubuntu shell to use the new default:"
echo "    bash ~/Senestro-Desktop/senestro-desktop-shell.sh"
echo ""
SWSHEOF
    chmod +x "$BASE_DIR/senestro-switch-shell.sh"
    printf "  ${GREEN}✓${NC} Created $BASE_DIR/senestro-switch-shell.sh\n"

    # ── senestro-desktop-gpu.sh ───────────────────────────────────────────────
    # Writes the GPU test body as a temp script inside Ubuntu rather than
    # passing it as an inline "bash -c '...'" string. Inline strings with
    # embedded newlines and backslash-continuations trigger fish's $'...' parser
    # error when the outer shell is fish. A script file avoids it entirely.
    cat > "$BASE_DIR/senestro-desktop-gpu.sh" << 'GPUTEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Senestro Linux Desktop — GPU Acceleration Test
# Termux-X11 must already be running before executing this script.
echo "Testing GPU acceleration inside Ubuntu..."
echo ""

# Write the test body as a real script inside Ubuntu, then execute it.
# Using a file avoids all inline bash -c quoting — safe under bash, fish, zsh.
proot-distro login ubuntu --shared-tmp --bind /sdcard:/sdcard -- bash << 'INNEREOF'
#!/bin/bash
_GPU_TMP=/tmp/senestro-gpu.sh
cat > "$_GPU_TMP" << 'GPUBODY'
#!/bin/bash
echo "--- OpenGL Info ---"
glxinfo 2>/dev/null | grep -i "opengl vendor\|opengl renderer\|opengl version" \
    || echo "glxinfo not found — install mesa-utils inside Ubuntu"
echo ""
echo "Launching glxgears (close window to exit)..."
glxgears 2>/dev/null || echo "glxgears not found"
GPUBODY
chmod +x "$_GPU_TMP"
DISPLAY=:__D__ bash "$_GPU_TMP"
INNEREOF
GPUTEOF
    sed -i "s/__D__/${_D}/g" "$BASE_DIR/senestro-desktop-gpu.sh"
    chmod +x "$BASE_DIR/senestro-desktop-gpu.sh"
    printf "  ${GREEN}✓${NC} Created $BASE_DIR/senestro-desktop-gpu.sh\n"
}


# =============================================================================
# COMPLETION MESSAGE
#
# Shown after all 10 installation steps succeed.
# Summarises what was installed and how to start the desktop.
# =============================================================================
show_completion() {
    echo ""
    echo -e "${GREEN}"
    cat << 'COMPLETE'

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║         ✅  INSTALLATION COMPLETE!  ✅                        ║
    ║                                                               ║
    ║              🎉 100% - All Done! 🎉                           ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

COMPLETE
    echo -e "${NC}"

    echo -e "${WHITE}🐧 Your Senestro Linux Desktop (Ubuntu + XFCE4) is ready!${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}  HOW TO USE:${NC}"
    echo ""
    echo -e "  1️⃣  Open the ${CYAN}Termux-X11${NC} app on your phone"
    echo -e "  2️⃣  Come back to Termux and run:"
    echo -e "       ${GREEN}bash $BASE_DIR/start-senestro-desktop.sh${NC}"
    echo -e "  3️⃣  Switch to ${CYAN}Termux-X11${NC} — your desktop appears!"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}  SCRIPTS:${NC}"
    echo -e "   🚀 Start desktop :  ${GREEN}bash $BASE_DIR/start-senestro-desktop.sh${NC}"
    echo -e "   🛑 Stop desktop  :  ${GREEN}bash $BASE_DIR/stop-senestro-desktop.sh${NC}"
    echo -e "   💻 Ubuntu shell  :  ${GREEN}bash $BASE_DIR/senestro-desktop-shell.sh${NC}"
    echo -e "   🐚 Switch shell  :  ${GREEN}bash $BASE_DIR/senestro-switch-shell.sh [bash|fish|zsh]${NC}"
    echo -e "   🔍 Test GPU      :  ${GREEN}bash $BASE_DIR/senestro-desktop-gpu.sh${NC}"
    echo -e "   📋 View log      :  ${GREEN}cat $LOG_DIR/senestro-desktop.log${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}📦 INSTALLED:${NC}"
    echo -e "   Termux : proot-distro, pulseaudio, termux-x11-nightly"
    echo -e "            mesa-zink, virglrenderer, mesa-demos, xorg-xrandr"
    echo -e "   Ubuntu : XFCE4 + goodies, xfce4-terminal, thunar, mousepad"
    echo -e "            Firefox ESR, VLC, VS Code (code), Git, Nano, Neovim"
    echo ""
    echo -e "${WHITE}💡 TIPS:${NC}"
    echo -e "   • Your Android storage is at ${GREEN}/sdcard${NC} inside Ubuntu"
    echo -e "   • Install more apps: ${GREEN}bash $BASE_DIR/senestro-desktop-shell.sh${NC}"
    echo -e "     then use ${GREEN}apt install <package>${NC} as normal"
    echo -e "   • Disable compositor in XFCE Tweaks for better performance"
    echo -e "   • Run ${GREEN}bash $BASE_DIR/senestro-desktop-gpu.sh${NC} to verify GPU"
    echo -e "   • Change shell anytime (inside Ubuntu): ${GREEN}chsh -s /bin/fish${NC}"
    echo -e "     or use the menu: ${GREEN}switch-shell${NC}  (e.g. ${GREEN}switch-shell fish${NC})"
    echo -e "   • Launch VLC from terminal (inside Ubuntu): ${GREEN}start-vlc${NC}"
    echo -e "   • Launch VS Code from the XFCE desktop: click the ${WHITE}VS Code${NC} icon"
    echo -e "     or from terminal (inside Ubuntu): ${GREEN}code --no-sandbox${NC}"
    echo -e "   • Repair any app without re-running the full installer:"
    echo -e "     ${GREEN}bash Senestro-Desktop.sh --fix-vlc${NC}      VLC media player"
    echo -e "     ${GREEN}bash Senestro-Desktop.sh --fix-firefox${NC}  Firefox ESR"
    echo -e "     ${GREEN}bash Senestro-Desktop.sh --fix-code-oss${NC} VS Code (Code OSS)"
    echo -e "     ${GREEN}bash Senestro-Desktop.sh --fix-all${NC}      all of the above"
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}


# =============================================================================
# FIX-VLC — Standalone VLC repair
#
# Reinstalls VLC if missing, re-applies the geteuid→getppid binary patch
# (required for root launch inside proot), reinstalls the start-vlc wrapper,
# and refreshes the XFCE desktop entry.
#
# Usage:
#   bash Senestro-Desktop.sh --fix-vlc
# =============================================================================
fix_vlc() {
    # Ensure log directory exists and clear the log for this run
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
    log "=== --fix-vlc run at $(date) ==="

    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🔧  Senestro Desktop — Fix VLC              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  Reinstalls VLC + root-launch patch + start-vlc wrapper.${NC}"
    echo ""
    echo -e "${GRAY}  Log: $LOG_FILE${NC}"
    echo ""

    # Pre-flight: Ubuntu must be installed
    if ! proot-distro login "$DISTRO" -- true > /dev/null 2>&1; then
        echo -e "  ${RED}✗  Ubuntu proot is not installed.${NC}"
        echo -e "  ${YELLOW}Run the full installer first:${NC} ${GREEN}bash Senestro-Desktop.sh${NC}"
        log "FAIL  --fix-vlc: Ubuntu proot not installed"
        exit 1
    fi
    printf "  ${GREEN}✓${NC} Ubuntu proot — found\n"
    echo ""

    # Read the display number baked into the start script; default to :1
    local _dh=":1"
    local _baked
    _baked=$(grep -oE 'DISPLAY=:[0-9]+' \
        "$BASE_DIR/start-senestro-desktop.sh" 2>/dev/null \
        | head -1 | cut -d= -f2 || true)
    [ -n "$_baked" ] && _dh="$_baked"

    # ── Step 1/2: Install VLC if missing ──────────────────────────────────────
    echo -e "${PURPLE}[1/2] Checking VLC installation...${NC}"
    echo ""
    local _vlc_inst_rc=0
    if is_apt_installed_inside_ubuntu "vlc"; then
        printf "  ${GREEN}✓${NC} VLC — already installed\n"
        log "SKIP  fix-vlc: vlc already present"
    else
        log "START fix-vlc: installing vlc"
        install_apt_inside_ubuntu "vlc" "VLC Media Player"
        _vlc_inst_rc=$?
    fi

    # ── Step 2/2: Binary patch + wrapper + desktop entry ──────────────────────
    echo ""
    echo -e "${PURPLE}[2/2] Applying root-launch patch + wrapper...${NC}"
    echo ""
    run_in_ubuntu "
        # Patch only if geteuid is still present (not already patched)
        if strings /usr/bin/vlc 2>/dev/null | grep -q 'geteuid'; then
            sed -i 's/geteuid/getppid/' /usr/bin/vlc
        fi
        cat > /usr/local/bin/start-vlc << VLCWRAPEOF
#!/bin/bash
# start-vlc — launch VLC as root in proot
# /usr/bin/vlc is patched (geteuid→getppid) at install time.
# --vout x11 forces the X11 video output; auto-detect picks broken
# GL/Wayland outputs inside proot and shows only audio.
export DISPLAY=${_dh}
exec vlc --vout x11 \"\\\$@\"
VLCWRAPEOF
        chmod +x /usr/local/bin/start-vlc
    "
    local _patch_rc=$?

    # Refresh the XFCE desktop entry
    run_in_ubuntu "mkdir -p /root/Desktop
printf '%s\n' \
    '[Desktop Entry]' \
    'Name=VLC Media Player' \
    'Comment=Play media files' \
    'Exec=start-vlc' \
    'Icon=vlc' \
    'Type=Application' \
    'Categories=AudioVideo;Player;' \
    > /root/Desktop/VLC.desktop
chmod +x /root/Desktop/VLC.desktop 2>/dev/null || true"

    local _vlc_rc=$(( _vlc_inst_rc + _patch_rc ))
    if [ "${_vlc_rc}" -eq 0 ]; then
        printf "  ${GREEN}✓${NC} VLC binary patched (geteuid→getppid)\n"
        printf "  ${GREEN}✓${NC} start-vlc wrapper installed (DISPLAY=${_dh})\n"
        printf "  ${GREEN}✓${NC} VLC desktop entry refreshed\n"
        log "OK    fix-vlc: patch + wrapper + entry (DISPLAY=${_dh})"
    else
        printf "  ${RED}✗${NC} VLC repair failed — check $LOG_FILE\n"
        log "FAIL  fix-vlc: exit ${_vlc_rc}"
    fi

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [ "${_vlc_rc}" -eq 0 ]; then
        echo -e "  ${GREEN}✅  VLC is ready!${NC}"
        echo ""
        echo -e "  Launch (inside Ubuntu shell) : ${GREEN}start-vlc${NC}"
        echo -e "  Open a file                  : ${GREEN}start-vlc /sdcard/movie.mp4${NC}"
    else
        echo -e "  ${RED}✗  VLC repair failed.  Check: ${GREEN}cat $LOG_FILE${NC}"
    fi
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log "=== --fix-vlc done (exit: ${_vlc_rc}) ==="
    return "${_vlc_rc}"
}


# =============================================================================
# FIX-FIREFOX — Standalone Firefox ESR repair
#
# Reinstalls Firefox ESR (real .deb, not snap) if missing and refreshes
# the XFCE desktop entry.
#
# Usage:
#   bash Senestro-Desktop.sh --fix-firefox
# =============================================================================
fix_firefox() {
    # Ensure log directory exists and clear the log for this run
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
    log "=== --fix-firefox run at $(date) ==="

    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🔧  Senestro Desktop — Fix Firefox          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  Reinstalls Firefox ESR (real .deb, not snap).${NC}"
    echo ""
    echo -e "${GRAY}  Log: $LOG_FILE${NC}"
    echo ""

    # Pre-flight: Ubuntu must be installed
    if ! proot-distro login "$DISTRO" -- true > /dev/null 2>&1; then
        echo -e "  ${RED}✗  Ubuntu proot is not installed.${NC}"
        echo -e "  ${YELLOW}Run the full installer first:${NC} ${GREEN}bash Senestro-Desktop.sh${NC}"
        log "FAIL  --fix-firefox: Ubuntu proot not installed"
        exit 1
    fi
    printf "  ${GREEN}✓${NC} Ubuntu proot — found\n"
    echo ""

    echo -e "${PURPLE}[1/1] Checking Firefox ESR installation...${NC}"
    echo ""
    local _ff_rc=0
    if is_apt_installed_inside_ubuntu "firefox-esr"; then
        printf "  ${GREEN}✓${NC} Firefox ESR — already installed\n"
        printf "  ${GRAY}(to force-reinstall: run  apt purge firefox-esr  inside Ubuntu, then re-run)${NC}\n"
        log "SKIP  fix-firefox: firefox-esr already present"
    else
        log "START fix-firefox: installing firefox-esr"
        install_apt_inside_ubuntu "firefox-esr" "Firefox ESR"
        _ff_rc=$?
    fi

    # Refresh the XFCE desktop entry regardless of install outcome
    run_in_ubuntu "mkdir -p /root/Desktop
printf '%s\n' \
    '[Desktop Entry]' \
    'Name=Firefox ESR' \
    'Comment=Web Browser' \
    'Exec=firefox-esr' \
    'Icon=firefox-esr' \
    'Type=Application' \
    'Categories=Network;WebBrowser;' \
    > /root/Desktop/Firefox.desktop
chmod +x /root/Desktop/Firefox.desktop 2>/dev/null || true"
    log "OK    fix-firefox: desktop entry refreshed"
    printf "  ${GREEN}✓${NC} Desktop entry refreshed (/root/Desktop/Firefox.desktop)\n"

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [ $_ff_rc -eq 0 ]; then
        echo -e "  ${GREEN}✅  Firefox ESR is ready!${NC}"
        echo ""
        echo -e "  Launch (inside Ubuntu shell) : ${GREEN}firefox-esr${NC}"
        echo -e "  Or click the Firefox icon on the XFCE desktop."
    else
        echo -e "  ${RED}✗  Firefox repair failed.  Check: ${GREEN}cat $LOG_FILE${NC}"
    fi
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log "=== --fix-firefox done (exit: $_ff_rc) ==="
    return "$_ff_rc"
}


# =============================================================================
# FIX-CODE-OSS — Standalone VS Code repair
#
# Reinstalls VS Code ("code") via the Microsoft apt repository if missing,
# and refreshes the XFCE desktop entry.
#
# Usage:
#   bash Senestro-Desktop.sh --fix-code-oss
# =============================================================================
fix_code_oss() {
    # Ensure log directory exists and clear the log for this run
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
    log "=== --fix-code-oss run at $(date) ==="

    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🔧  Senestro Desktop — Fix Code OSS         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  Reinstalls VS Code (code) via Microsoft apt repo + desktop entry.${NC}"
    echo ""
    echo -e "${GRAY}  Log: $LOG_FILE${NC}"
    echo ""

    # Pre-flight: Ubuntu must be installed
    if ! proot-distro login "$DISTRO" -- true > /dev/null 2>&1; then
        echo -e "  ${RED}✗  Ubuntu proot is not installed.${NC}"
        echo -e "  ${YELLOW}Run the full installer first:${NC} ${GREEN}bash Senestro-Desktop.sh${NC}"
        log "FAIL  --fix-code-oss: Ubuntu proot not installed"
        exit 1
    fi
    printf "  ${GREEN}✓${NC} Ubuntu proot — found\n"
    echo ""

    # ── Step 1/2: Install VS Code if missing ──────────────────────────────────
    echo -e "${PURPLE}[1/2] Checking VS Code installation...${NC}"
    echo ""
    local _co_rc=0
    local _already
    _already=$(proot-distro login "$DISTRO" --shared-tmp --bind /sdcard:/sdcard -- \
        bash -c "dpkg-query -W -f='\${Status}' code 2>/dev/null || true" 2>/dev/null || true)
    if echo "$_already" | grep -q "install ok installed"; then
        printf "  ${GREEN}✓${NC} VS Code (code) — already installed\n"
        printf "  ${GRAY}(to force-reinstall: apt purge code inside Ubuntu, then re-run)${NC}\n"
        log "SKIP  fix-code-oss: code already installed"
    else
        log "START fix-code-oss: installing via Microsoft apt repo"
        install_vscode_inside_ubuntu
        _co_rc=$?
    fi

    # ── Step 2/2: Refresh the XFCE desktop entry ──────────────────────────────
    echo ""
    echo -e "${PURPLE}[2/2] Refreshing desktop entry...${NC}"
    echo ""
    run_in_ubuntu "mkdir -p /root/Desktop/User/.vscode
printf '%s\n' \
    '[Desktop Entry]' \
    'Name=VS Code' \
    'Comment=Code Editor' \
    'Exec=code --no-sandbox --user-data-dir=/root/Desktop/User/.vscode' \
    'Icon=code' \
    'Type=Application' \
    'Categories=Development;' \
    > /root/Desktop/VSCode.desktop
chmod +x /root/Desktop/VSCode.desktop 2>/dev/null || true"
    printf "  ${GREEN}✓${NC} Desktop entry refreshed (/root/Desktop/VSCode.desktop)\n"
    log "OK    fix-code-oss: desktop entry refreshed"

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    if [ $_co_rc -eq 0 ]; then
        echo -e "  ${GREEN}✅  VS Code is ready!${NC}"
        echo ""
        echo -e "  Launch (XFCE desktop)         : click the ${WHITE}VS Code${NC} icon"
        echo -e "  Launch (inside Ubuntu shell)  : ${GREEN}code --no-sandbox${NC}"
    else
        echo -e "  ${RED}✗  VS Code install failed.  Check: ${GREEN}cat $LOG_FILE${NC}"
    fi
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log "=== --fix-code-oss done (exit: $_co_rc) ==="
    return "$_co_rc"
}


# =============================================================================
# FIX-ALL — Run all three repair operations in sequence
#
# Shows a numbered section header per tool, runs fix_vlc, fix_firefox,
# and fix_code_oss in order (sharing a single cleared log), then prints
# a combined pass/fail summary.
#
# Usage:
#   bash Senestro-Desktop.sh --fix-all
# =============================================================================
fix_all() {
    # Clear the log once at the top — sub-functions will append to it
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
    log "=== --fix-all run at $(date) ==="

    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🔧  Senestro Desktop — Fix All              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  Repairs VLC, Firefox ESR, and VS Code (Code OSS).${NC}"
    echo -e "${WHITE}  Each tool is checked and reinstalled only if missing.${NC}"
    echo ""
    echo -e "${GRAY}  Log: $LOG_FILE${NC}"
    echo ""

    # Pre-flight: Ubuntu must be installed (checked once, not per sub-function)
    if ! proot-distro login "$DISTRO" -- true > /dev/null 2>&1; then
        echo -e "  ${RED}✗  Ubuntu proot is not installed.${NC}"
        echo -e "  ${YELLOW}Run the full installer first:${NC} ${GREEN}bash Senestro-Desktop.sh${NC}"
        log "FAIL  --fix-all: Ubuntu proot not installed"
        exit 1
    fi
    printf "  ${GREEN}✓${NC} Ubuntu proot — found\n"
    echo ""

    local _fa_vlc_rc=0
    local _fa_ff_rc=0
    local _fa_co_rc=0

    # ── Step 1/3: VLC ─────────────────────────────────────────────────────────
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  Step 1 / 3 — VLC Media Player${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    # Call sub-function body directly to avoid redundant log clear + clear screen
    fix_vlc
    _fa_vlc_rc=$?

    # ── Step 2/3: Firefox ─────────────────────────────────────────────────────
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  Step 2 / 3 — Firefox ESR${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    fix_firefox
    _fa_ff_rc=$?

    # ── Step 3/3: Code OSS ────────────────────────────────────────────────────
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  Step 3 / 3 — VS Code (Code OSS)${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    fix_code_oss
    _fa_co_rc=$?

    # ── Combined summary ──────────────────────────────────────────────────────
    local _fa_total=$(( _fa_vlc_rc + _fa_ff_rc + _fa_co_rc ))
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Fix-All Summary                             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    local _icon_vlc="${GREEN}✅${NC}"; [ "$_fa_vlc_rc" -ne 0 ] && _icon_vlc="${RED}✗${NC}"
    local _icon_ff="${GREEN}✅${NC}";  [ "$_fa_ff_rc"  -ne 0 ] && _icon_ff="${RED}✗${NC}"
    local _icon_co="${GREEN}✅${NC}";  [ "$_fa_co_rc"  -ne 0 ] && _icon_co="${RED}✗${NC}"
    echo -e "  Step 1 / 3  VLC Media Player     — $(echo -e "$_icon_vlc")"
    echo -e "  Step 2 / 3  Firefox ESR           — $(echo -e "$_icon_ff")"
    echo -e "  Step 3 / 3  VS Code (Code OSS)    — $(echo -e "$_icon_co")"
    echo ""
    if [ "$_fa_total" -eq 0 ]; then
        echo -e "  ${GREEN}All repairs completed successfully.${NC}"
    else
        echo -e "  ${RED}One or more repairs failed.  Check: ${GREEN}cat $LOG_FILE${NC}"
    fi
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log "=== --fix-all done (vlc:$_fa_vlc_rc ff:$_fa_ff_rc co:$_fa_co_rc total:$_fa_total) ==="
    return "$_fa_total"
}


# =============================================================================
# UNINSTALL — Remove Ubuntu rootfs, cache, config file, and launcher files
#
# The user is asked to confirm the overall uninstall once upfront, then each
# optional item (download cache, leftover rootfs/config dirs, GPU config file)
# is offered as a separate yes/no prompt so they keep full control.
#
# Steps (v2.6 — now 4 steps):
#   1. Remove Ubuntu proot-distro rootfs
#   2. Optionally remove proot-distro download cache + leftover config dirs
#   3. Optionally remove GPU config file ($HOME/.config/senestro-desktop-config.sh)
#   4. Remove the Senestro-Desktop launcher directory ($HOME/Senestro-Desktop)
#
# Usage:
#   bash Senestro-Desktop.sh --uninstall
# =============================================================================
uninstall_senestro() {
    # Ensure log directory exists and clear the log for this run
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
    log "=== --uninstall run at $(date) ==="

    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🗑  Senestro Desktop — Uninstall            ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}  This will permanently remove:${NC}"
    echo -e "    ${WHITE}•${NC} Ubuntu proot-distro rootfs (all Ubuntu data & apps)"
    echo -e "    ${WHITE}•${NC} All launcher scripts in ${WHITE}$BASE_DIR${NC}"
    echo -e "    ${WHITE}•${NC} GPU config file at ${WHITE}$HOME/.config/senestro-desktop-config.sh${NC} (optional)"
    echo ""
    echo -e "${YELLOW}  ⚠  This cannot be undone.${NC}"
    echo ""
    printf "  ${YELLOW}Type ${WHITE}yes${YELLOW} to confirm, or press Enter to cancel: ${NC}"
    read -r _CONFIRM
    echo ""

    if [ "$_CONFIRM" != "yes" ]; then
        echo -e "  ${GREEN}Uninstall cancelled — nothing was changed.${NC}"
        echo ""
        exit 0
    fi

    # ── Step 1/4: Remove Ubuntu proot-distro rootfs ───────────────────────────
    echo -e "${PURPLE}[1/4] Removing Ubuntu proot-distro rootfs...${NC}"
    echo ""
    if proot-distro login "$DISTRO" -- true > /dev/null 2>&1; then
        printf "  ${YELLOW}⏳${NC} Removing Ubuntu rootfs (this may take a moment)"
        (proot-distro remove "$DISTRO" >> "$LOG_FILE" 2>&1) &
        local _pd_pid=$!
        while kill -0 "$_pd_pid" 2>/dev/null; do
            printf "${CYAN}.${NC}"
            sleep 1
        done
        wait "$_pd_pid"
        local _pd_rc=$?
        if [ $_pd_rc -eq 0 ]; then
            printf " ${GREEN}✓${NC}\n"
            log "OK    uninstall: Ubuntu rootfs removed"
        else
            printf " ${RED}✗ (check $LOG_FILE)${NC}\n"
            log "FAIL  uninstall: proot-distro remove exit $_pd_rc"
        fi
    else
        printf "  ${GRAY}Ubuntu rootfs not found — skipping.${NC}\n"
        log "SKIP  uninstall: Ubuntu rootfs not present"
    fi

    # ── Step 2/4: Optionally remove proot-distro cache & leftover config ──────
    echo ""
    echo -e "${PURPLE}[2/4] proot-distro cache & config files...${NC}"
    echo ""
    local _PROOT_DATA_DIR="$HOME/.local/share/proot-distro"
    local _CACHE_DIR="$_PROOT_DATA_DIR/dlcache"
    local _ROOTFS_DIR="$_PROOT_DATA_DIR/installed-rootfs"

    # 2a: Download cache (can be large — ~200 MB)
    if [ -d "$_CACHE_DIR" ]; then
        local _CACHE_SIZE
        _CACHE_SIZE=$(du -sh "$_CACHE_DIR" 2>/dev/null | cut -f1 || echo "?")
        echo -e "  Download cache : ${WHITE}$_CACHE_DIR${NC} (${_CACHE_SIZE})"
        printf "  ${YELLOW}Delete download cache? [y/N]: ${NC}"
        read -r _DEL_CACHE
        echo ""
        if [[ "$_DEL_CACHE" =~ ^[Yy]$ ]]; then
            rm -rf "$_CACHE_DIR"
            printf "  ${GREEN}✓${NC} Download cache removed\n"
            log "OK    uninstall: proot-distro dlcache removed"
        else
            printf "  ${GRAY}Download cache kept — skipping.\n${NC}"
            log "INFO  uninstall: proot-distro dlcache kept by user choice"
        fi
    else
        printf "  ${GRAY}No download cache found — skipping.${NC}\n"
        log "INFO  uninstall: no dlcache found"
    fi
    echo ""

    # 2b: Remaining rootfs / config directories
    local _LEFTOVER_DIR=""
    if [ -d "$_ROOTFS_DIR/ubuntu" ]; then
        _LEFTOVER_DIR="$_ROOTFS_DIR/ubuntu"
    elif [ -d "$_PROOT_DATA_DIR" ]; then
        _LEFTOVER_DIR="$_PROOT_DATA_DIR"
    fi

    if [ -n "$_LEFTOVER_DIR" ]; then
        local _CFG_SIZE
        _CFG_SIZE=$(du -sh "$_LEFTOVER_DIR" 2>/dev/null | cut -f1 || echo "?")
        echo -e "  Config / rootfs: ${WHITE}$_LEFTOVER_DIR${NC} (${_CFG_SIZE})"
        printf "  ${YELLOW}Also delete all remaining proot-distro config & rootfs files? [y/N]: ${NC}"
        read -r _DEL_CFG
        echo ""
        if [[ "$_DEL_CFG" =~ ^[Yy]$ ]]; then
            rm -rf "$_LEFTOVER_DIR"
            printf "  ${GREEN}✓${NC} proot-distro config/rootfs files removed\n"
            log "OK    uninstall: proot-distro config dir removed ($_LEFTOVER_DIR)"
        else
            printf "  ${GRAY}Config files kept — skipping.${NC}\n"
            log "INFO  uninstall: proot-distro config kept by user choice"
        fi
    else
        printf "  ${GRAY}No proot-distro config files found — skipping.${NC}\n"
        log "INFO  uninstall: no proot-distro config dir found"
    fi

    # ── Step 3/4: Optionally remove GPU config file ───────────────────────────
    # This file was written by the installer to $HOME/.config/ and is sourced
    # by start-senestro-desktop.sh. Removing it is optional — the user may want
    # to keep their GPU tuning for a future reinstall.
    echo ""
    echo -e "${PURPLE}[3/4] GPU config file...${NC}"
    echo ""
    local _GPU_CFG="$HOME/.config/senestro-desktop-config.sh"
    if [ -f "$_GPU_CFG" ]; then
        echo -e "  Config file: ${WHITE}$_GPU_CFG${NC}"
        printf "  ${YELLOW}Delete GPU config file? [y/N]: ${NC}"
        read -r _DEL_GPU_CFG
        echo ""
        if [[ "$_DEL_GPU_CFG" =~ ^[Yy]$ ]]; then
            rm -f "$_GPU_CFG"
            printf "  ${GREEN}✓${NC} GPU config file removed\n"
            log "OK    uninstall: GPU config file removed ($_GPU_CFG)"
        else
            printf "  ${GRAY}GPU config file kept — skipping.${NC}\n"
            log "INFO  uninstall: GPU config file kept by user choice"
        fi
    else
        printf "  ${GRAY}GPU config file not found — skipping.${NC}\n"
        log "INFO  uninstall: GPU config file not present ($_GPU_CFG)"
    fi

    # ── Step 4/4: Remove Senestro-Desktop launcher directory ─────────────────
    # Log before deletion so the last write succeeds before the directory is gone
    echo ""
    echo -e "${PURPLE}[4/4] Removing Senestro-Desktop files...${NC}"
    echo ""
    if [ -d "$BASE_DIR" ]; then
        log "OK    uninstall: removing $BASE_DIR"
        rm -rf "$BASE_DIR"
        printf "  ${GREEN}✓${NC} Removed $BASE_DIR\n"
    else
        printf "  ${GRAY}$BASE_DIR not found — skipping.${NC}\n"
        log "INFO  uninstall: $BASE_DIR not found"
    fi

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}✅  Senestro Desktop has been uninstalled.${NC}"
    echo ""
    echo -e "  ${GRAY}To reinstall at any time, run:${NC}"
    echo -e "  ${GREEN}bash Senestro-Desktop.sh${NC}"
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}


# =============================================================================
# MAIN — Full installation flow
#
# Sequence:
#   0. Setup log (cleared here — fresh log for every install run)
#   1. Show banner
#   2. Offer Install / Uninstall choice
#   3. Pre-install info + confirmation prompt
#   4. detect_device (GPU family detection — sets GPU_DRIVER)
#   5–14. Installation steps 1–10 (update → launchers)
#   15. Show completion message
# =============================================================================
main() {
    # Ensure the log directory exists and clear any previous log content.
    # Every install run starts with a fresh log file — no accumulated history.
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
    {
        echo "========================================"
        echo " Senestro Desktop Installer v2.6 — $(date)"
        echo "========================================"
    } >> "$LOG_FILE"

    show_banner

    # ── Install or Uninstall? ─────────────────────────────────────────────────
    echo -e "  ${CYAN}What would you like to do?${NC}"
    echo ""
    echo -e "    ${GREEN}[1]${NC} Install   — set up Ubuntu + XFCE4 desktop"
    echo -e "    ${RED}[2]${NC} Uninstall — remove Ubuntu rootfs and all Senestro files"
    echo ""
    printf "  Choose [1/2, default: 1 — Install]: "
    read -r _MODE_CHOICE
    echo ""

    if [[ "$_MODE_CHOICE" == "2" ]]; then
        uninstall_senestro
        exit 0
    fi

    # ── Pre-flight checks: internet connectivity and available disk space ──────
    # These run before any user confirmation so the user gets immediate,
    # actionable feedback if the device isn't ready for a long download.
    check_internet
    check_disk_space
    echo ""

    # ── Pre-install information and confirmation ───────────────────────────────
    echo -e "${WHITE}  Installs full Ubuntu Linux + XFCE4 desktop on Android${NC}"
    echo -e "${WHITE}  using proot-distro and Termux-X11.${NC}"
    echo ""
    echo -e "${GRAY}  Estimated time : 20–40 min (depends on internet speed)${NC}"
    echo -e "${GRAY}  Ubuntu rootfs  : ~200 MB download${NC}"
    echo -e "${GRAY}  Full log       : $LOG_DIR/senestro-desktop.log${NC}"
    echo ""
    echo -e "${YELLOW}  ⚠  Make sure you have a stable internet connection.${NC}"
    echo -e "${YELLOW}  Press Enter to begin, or Ctrl+C to cancel...${NC}"
    read -r

    # Run all installation steps in order
    detect_device
    step_update
    step_repos
    step_termux_pkgs
    step_install_ubuntu
    step_user_setup
    step_ubuntu_update
    step_ubuntu_desktop
    step_ubuntu_apps
    step_configure
    step_proot_helpers
    step_launchers

    log "=== Installation finished successfully ==="
    show_completion
}


# =============================================================================
# SCRIPT METADATA
#
# SCRIPT_VERSION — the canonical version string for this file.
#   Used by --version and by --update to detect whether a downloaded copy
#   is actually newer than the one currently running.
#
# SCRIPT_UPDATE_URL — raw URL of the latest published script.
#   Update this to the real raw-file URL wherever you host the script
#   (e.g. a GitHub Gist raw link or a direct download URL).
#   The --update flag downloads from this URL and replaces this file.
# =============================================================================
SCRIPT_VERSION="2.6"
SCRIPT_UPDATE_URL="https://raw.githubusercontent.com/Senestro88/senestro-desktop/main/Senestro-Desktop.sh"


# =============================================================================
# SHOW VERSION
#
# Prints the current script version to stdout.
#
# Usage:
#   bash Senestro-Desktop.sh --version
# =============================================================================
show_version() {
    echo ""
    echo -e "${CYAN}  🐧 Senestro Linux Desktop${NC}"
    echo -e "     Version : ${WHITE}${SCRIPT_VERSION}${NC}"
    echo -e "     File    : ${WHITE}${BASH_SOURCE[0]}${NC}"
    echo ""
}


# =============================================================================
# SHOW HELP
#
# Prints all available command-line flags and their descriptions.
#
# Usage:
#   bash Senestro-Desktop.sh --help
# =============================================================================
show_help() {
    clear
    echo -e "${CYAN}"
    cat << 'HELPBANNER'
    ╔══════════════════════════════════════════════╗
    ║   🐧  SENESTRO LINUX DESKTOP v2.6  🐧        ║
    ╚══════════════════════════════════════════════╝
HELPBANNER
    echo -e "${NC}"

    echo -e "${WHITE}  USAGE${NC}"
    echo -e "    ${GREEN}bash Senestro-Desktop.sh${NC} ${GRAY}[flag]${NC}"
    echo ""
    echo -e "${WHITE}  FLAGS${NC}"
    echo ""
    echo -e "    ${GREEN}(no flag)${NC}          Run the full installer"
    echo -e "                       Installs Ubuntu + XFCE4 + all apps"
    echo ""
    echo -e "    ${GREEN}--update${NC}           Self-update this script"
    echo -e "                       Downloads the latest version and replaces"
    echo -e "                       this file in-place — your data is kept"
    echo ""
    echo -e "    ${GREEN}--uninstall${NC}        Remove everything Senestro installed"
    echo -e "                       Ubuntu rootfs, launcher scripts, GPU config,"
    echo -e "                       and proot-distro cache (each item optional)"
    echo ""
    echo -e "    ${GREEN}--fix-vlc${NC}          Repair VLC"
    echo -e "                       Reinstalls VLC, applies root-launch patch,"
    echo -e "                       and refreshes the XFCE desktop entry"
    echo ""
    echo -e "    ${GREEN}--fix-firefox${NC}      Repair Firefox ESR"
    echo -e "                       Reinstalls Firefox ESR (.deb, not snap)"
    echo -e "                       and refreshes the XFCE desktop entry"
    echo ""
    echo -e "    ${GREEN}--fix-code-oss${NC}     Repair VS Code"
    echo -e "                       Reinstalls code via Microsoft apt repo"
    echo -e "                       and refreshes the XFCE desktop entry"
    echo ""
    echo -e "    ${GREEN}--fix-all${NC}          Repair all three apps"
    echo -e "                       Runs --fix-vlc, --fix-firefox, --fix-code-oss"
    echo -e "                       in sequence with a combined summary"
    echo ""
    echo -e "    ${GREEN}--changelog${NC}        Show version history"
    echo -e "                       Extracts the changelog from this script's"
    echo -e "                       own header — no network connection needed"
    echo ""
    echo -e "    ${GREEN}--status${NC}           Check installation state"
    echo -e "                       Shows which packages, scripts, and config"
    echo -e "                       files are present or missing"
    echo ""
    echo -e "    ${GREEN}--version${NC}          Print the current version and exit"
    echo ""
    echo -e "    ${GREEN}--help${NC}  ${GREEN}-h${NC}         Show this help and exit"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}  FULL FEATURES (v2.6)${NC}"
    echo ""
    echo -e "   01  GPU acceleration auto-setup (Turnip/Zink/VirGL)"
    echo -e "   02  /sdcard shared with Ubuntu on every login"
    echo -e "   03  90-second pkg-update timeout guard"
    echo -e "   04  Skip-if-installed checks (Termux + Ubuntu)"
    echo -e "   05  Log cleared on every run — no stale history"
    echo -e "   06  One-click launcher scripts (start/stop/shell/GPU/switch-shell)"
    echo -e "   07  chsh PAM bypass shim (/usr/local/bin/chsh)"
    echo -e "   08  Default shell picker (bash/fish/zsh/dash) at setup"
    echo -e "   09  Optional new Ubuntu user + passwordless sudo"
    echo -e "   10  VLC root bypass (ELF binary patch + start-vlc wrapper)"
    echo -e "   11  fish PATH fix (/etc/fish/conf.d/senestro-path.fish)"
    echo -e "   12  VS Code native desktop app via Microsoft apt repo"
    echo -e "   13  D-Bus machine-id auto-repair on every desktop launch"
    echo -e "   14  Standalone repair flags (--fix-vlc/firefox/code-oss/all)"
    echo -e "   15  Full uninstall with per-item prompts + GPU config removal"
    echo -e "   16  Self-update (--update) — replaces script in-place"
    echo -e "   17  Changelog viewer (--changelog) — offline, from script header"
    echo -e "   18  Installation status checker (--status)"
    echo -e "   19  Internet + disk space pre-checks before every install"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Log: ${GRAY}$LOG_FILE${NC}"
    echo ""
}


# =============================================================================
# SHOW CHANGELOG
#
# Extracts and displays the version history that is embedded directly in
# this script's own header between [CHANGELOG_START] and [CHANGELOG_END]
# markers — no network connection required.
#
# Usage:
#   bash Senestro-Desktop.sh --changelog
# =============================================================================
show_changelog() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  📋  Senestro Desktop — Version History      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Current version: ${WHITE}${SCRIPT_VERSION}${NC}"
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Extract lines between the CHANGELOG_START and CHANGELOG_END markers
    # embedded in this script's own header, strip leading "#  " comment chars,
    # and colour each version line cyan.
    local _SELF="${BASH_SOURCE[0]}"
    local _IN_CL=0
    while IFS= read -r _line; do
        if echo "$_line" | grep -q '\[CHANGELOG_START\]'; then
            _IN_CL=1
            continue
        fi
        if echo "$_line" | grep -q '\[CHANGELOG_END\]'; then
            break
        fi
        if [ $_IN_CL -eq 1 ]; then
            # Strip leading "#  " comment prefix
            local _clean="${_line###  }"
            _clean="${_clean###}"
            # Highlight version headings (lines starting with "v")
            if echo "$_clean" | grep -qE '^v[0-9]'; then
                echo -e "  ${CYAN}${_clean}${NC}"
            else
                echo -e "  ${GRAY}${_clean}${NC}"
            fi
        fi
    done < "$_SELF"

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}


# =============================================================================
# SHOW STATUS
#
# Checks and reports the current installation state without making any changes.
# Useful after a partial install, before running --fix-*, or just to confirm
# what is and isn't present on the device.
#
# Checks performed:
#   Termux packages : proot-distro, pulseaudio, termux-x11-nightly,
#                     mesa-zink, mesa-demos, xorg-xrandr
#   Ubuntu proot    : whether proot-distro can log into Ubuntu
#   Ubuntu packages : vlc, firefox-esr, code, git, neovim (sampled)
#   Launcher scripts: all five scripts in BASE_DIR
#   Config file     : $HOME/.config/senestro-desktop-config.sh
#   Log file        : size and last-modified date
#
# Usage:
#   bash Senestro-Desktop.sh --status
# =============================================================================
show_status() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🔍  Senestro Desktop — Installation Status  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Version : ${WHITE}${SCRIPT_VERSION}${NC}"
    echo -e "  Date    : ${GRAY}$(date)${NC}"
    echo ""

    # ── Helper: print a status line ──────────────────────────────────────────
    # Usage: _status_line "Label" 0|1   (1 = present/OK, 0 = missing)
    _status_line() {
        local _label="$1"
        local _ok="$2"
        local _note="${3:-}"
        if [ "$_ok" -eq 1 ]; then
            printf "    ${GREEN}✓${NC}  %-40s ${GRAY}%s${NC}\n" "$_label" "$_note"
        else
            printf "    ${RED}✗${NC}  %-40s ${YELLOW}%s${NC}\n" "$_label" "${_note:-missing}"
        fi
    }

    # ── Termux packages ───────────────────────────────────────────────────────
    echo -e "${WHITE}  Termux packages:${NC}"
    echo ""
    for _pkg in proot-distro pulseaudio termux-x11-nightly \
                mesa-zink mesa-demos xorg-xrandr; do
        if is_pkg_installed "$_pkg"; then
            _status_line "$_pkg" 1 "installed"
        else
            _status_line "$_pkg" 0
        fi
    done
    # virglrenderer (either variant)
    if is_pkg_installed "virglrenderer-mesa-zink"; then
        _status_line "virglrenderer-mesa-zink" 1 "installed (Adreno/Zink)"
    elif is_pkg_installed "virglrenderer-android"; then
        _status_line "virglrenderer-android" 1 "installed (Android GLES)"
    else
        _status_line "virglrenderer" 0 "neither variant installed"
    fi
    echo ""

    # ── Ubuntu proot ──────────────────────────────────────────────────────────
    echo -e "${WHITE}  Ubuntu proot:${NC}"
    echo ""
    if proot-distro login "$DISTRO" -- true > /dev/null 2>&1; then
        _status_line "Ubuntu rootfs" 1 "accessible"

        # Sample of Ubuntu-side packages (fast dpkg -s checks)
        echo ""
        echo -e "${WHITE}  Ubuntu packages (sampled):${NC}"
        echo ""
        for _upkg in xfce4 xfce4-terminal firefox-esr vlc code git neovim; do
            if is_apt_installed_inside_ubuntu "$_upkg"; then
                _status_line "$_upkg" 1 "installed"
            else
                _status_line "$_upkg" 0
            fi
        done
    else
        _status_line "Ubuntu rootfs" 0 "not installed or inaccessible"
    fi
    echo ""

    # ── Launcher scripts ──────────────────────────────────────────────────────
    echo -e "${WHITE}  Launcher scripts  (${GRAY}${BASE_DIR}${WHITE}):${NC}"
    echo ""
    for _script in \
        "start-senestro-desktop.sh" \
        "stop-senestro-desktop.sh" \
        "senestro-desktop-shell.sh" \
        "senestro-switch-shell.sh" \
        "senestro-desktop-gpu.sh"; do
        if [ -f "$BASE_DIR/$_script" ]; then
            _status_line "$_script" 1 "present"
        else
            _status_line "$_script" 0
        fi
    done
    echo ""

    # ── Config file ───────────────────────────────────────────────────────────
    echo -e "${WHITE}  Config file:${NC}"
    echo ""
    local _GPU_CFG="$HOME/.config/senestro-desktop-config.sh"
    if [ -f "$_GPU_CFG" ]; then
        _status_line "senestro-desktop-config.sh" 1 "$_GPU_CFG"
    else
        _status_line "senestro-desktop-config.sh" 0 "$_GPU_CFG"
    fi
    echo ""

    # ── Log file ──────────────────────────────────────────────────────────────
    echo -e "${WHITE}  Log file:${NC}"
    echo ""
    if [ -f "$LOG_FILE" ]; then
        local _LOG_SIZE
        _LOG_SIZE=$(du -sh "$LOG_FILE" 2>/dev/null | cut -f1 || echo "?")
        local _LOG_DATE
        _LOG_DATE=$(date -r "$LOG_FILE" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")
        _status_line "senestro-desktop.log" 1 "${_LOG_SIZE} — last run: ${_LOG_DATE}"
    else
        _status_line "senestro-desktop.log" 0 "no log yet — install not run"
    fi
    echo ""

    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  Run ${GREEN}bash Senestro-Desktop.sh --help${NC} to see all available flags."
    echo ""

    # Clean up the local helper function
    unset -f _status_line
}


# =============================================================================
# SELF-UPDATE
#
# Downloads the latest version of this script from SCRIPT_UPDATE_URL,
# verifies it is a valid bash script (shebang + bash -n syntax check),
# shows a diff of the version line so the user can confirm, then
# replaces this file in-place and re-runs with the same arguments.
#
# Safety guarantees:
#   - The download is saved to a temp file first; the live script is never
#     touched if the download or verification fails.
#   - A backup of the current script is written alongside it before overwrite.
#   - The download respects the 90-second timeout used elsewhere.
#   - curl is tried first; wget is used as a fallback.
#
# Usage:
#   bash Senestro-Desktop.sh --update
# =============================================================================
update_self() {
    mkdir -p "$LOG_DIR"
    : > "$LOG_FILE"
    log "=== --update run at $(date) ==="

    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  🔄  Senestro Desktop — Self Update          ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Current version : ${WHITE}${SCRIPT_VERSION}${NC}"
    echo -e "  Update URL      : ${GRAY}${SCRIPT_UPDATE_URL}${NC}"
    echo ""

    # ── Locate the script's own path ─────────────────────────────────────────
    # BASH_SOURCE[0] gives the path as it was invoked. Resolve to absolute.
    local _SELF
    _SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

    if [ ! -f "$_SELF" ]; then
        echo -e "  ${RED}✗  Cannot determine script path — aborting.${NC}"
        log "FAIL  --update: script path unresolvable"
        exit 1
    fi
    echo -e "  Script path     : ${GRAY}${_SELF}${NC}"
    echo ""

    # ── Check that we have a downloader ──────────────────────────────────────
    local _DL_CMD=""
    if command -v curl > /dev/null 2>&1; then
        _DL_CMD="curl"
    elif command -v wget > /dev/null 2>&1; then
        _DL_CMD="wget"
    else
        echo -e "  ${RED}✗  Neither curl nor wget is installed.${NC}"
        echo -e "  ${YELLOW}Install one first:${NC} ${GREEN}pkg install curl${NC}"
        log "FAIL  --update: no downloader available"
        exit 1
    fi
    echo -e "  Downloader      : ${WHITE}${_DL_CMD}${NC}"
    echo ""

    # ── Download to a temp file ───────────────────────────────────────────────
    local _TMP_FILE
    _TMP_FILE="$(mktemp /tmp/senestro-update-XXXXXX.sh)"

    printf "  ${YELLOW}⏳${NC} Downloading latest version"
    log "START --update: downloading from $SCRIPT_UPDATE_URL"

    local _DL_RC=0
    if [ "$_DL_CMD" = "curl" ]; then
        (timeout 90 curl -fsSL --connect-timeout 15 \
            "$SCRIPT_UPDATE_URL" -o "$_TMP_FILE" >> "$LOG_FILE" 2>&1) &
    else
        (timeout 90 wget -q --timeout=15 \
            "$SCRIPT_UPDATE_URL" -O "$_TMP_FILE" >> "$LOG_FILE" 2>&1) &
    fi
    local _DL_PID=$!
    while kill -0 "$_DL_PID" 2>/dev/null; do
        printf "${CYAN}.${NC}"
        sleep 1
    done
    wait "$_DL_PID"
    _DL_RC=$?

    if [ $_DL_RC -ne 0 ]; then
        rm -f "$_TMP_FILE"
        echo -e " ${RED}✗${NC}"
        echo ""
        echo -e "  ${RED}✗  Download failed (exit $_DL_RC).${NC}"
        echo -e "  ${YELLOW}Check your internet connection or update URL.${NC}"
        echo -e "  ${GRAY}  Log: $LOG_FILE${NC}"
        log "FAIL  --update: download failed (exit $_DL_RC)"
        exit 1
    fi
    echo -e " ${GREEN}✓${NC}"
    log "OK    --update: downloaded to $_TMP_FILE"

    # ── Verify the download is a real bash script ─────────────────────────────
    echo ""
    printf "  ${YELLOW}⏳${NC} Verifying downloaded file..."

    # Must start with a bash shebang line
    local _SHEBANG
    _SHEBANG=$(head -1 "$_TMP_FILE" 2>/dev/null)
    if ! echo "$_SHEBANG" | grep -q 'bash'; then
        rm -f "$_TMP_FILE"
        printf " ${RED}✗${NC}\n"
        echo ""
        echo -e "  ${RED}✗  Downloaded file does not look like a bash script.${NC}"
        echo -e "  ${YELLOW}Expected a bash shebang on line 1. Aborting.${NC}"
        log "FAIL  --update: shebang check failed (got: $_SHEBANG)"
        exit 1
    fi

    # Bash syntax check — catches obviously broken downloads (truncated, HTML error pages, etc.)
    if ! bash -n "$_TMP_FILE" 2>> "$LOG_FILE"; then
        rm -f "$_TMP_FILE"
        printf " ${RED}✗${NC}\n"
        echo ""
        echo -e "  ${RED}✗  Downloaded script failed syntax check.${NC}"
        echo -e "  ${GRAY}  Log: $LOG_FILE${NC}"
        log "FAIL  --update: bash -n syntax check failed"
        exit 1
    fi
    printf " ${GREEN}✓${NC}\n"
    log "OK    --update: verification passed"

    # ── Extract version from the downloaded script ────────────────────────────
    local _NEW_VERSION
    _NEW_VERSION=$(grep -oE '^SCRIPT_VERSION="[^"]+"' "$_TMP_FILE" 2>/dev/null \
        | head -1 | cut -d'"' -f2 || echo "unknown")

    echo ""
    echo -e "  Downloaded version : ${WHITE}${_NEW_VERSION}${NC}"
    echo -e "  Current version    : ${WHITE}${SCRIPT_VERSION}${NC}"
    echo ""

    # ── Warn if the downloaded version is not newer ───────────────────────────
    if [ "$_NEW_VERSION" = "$SCRIPT_VERSION" ]; then
        echo -e "  ${YELLOW}⚠${NC}  You are already on version ${WHITE}${SCRIPT_VERSION}${NC}."
        echo ""
        printf "  ${YELLOW}Force overwrite anyway? [y/N]: ${NC}"
        read -r _FORCE_UPDATE
        echo ""
        if ! [[ "$_FORCE_UPDATE" =~ ^[Yy]$ ]]; then
            rm -f "$_TMP_FILE"
            echo -e "  ${GREEN}Update cancelled — script unchanged.${NC}"
            echo ""
            log "INFO  --update: same version, user cancelled overwrite"
            exit 0
        fi
    fi

    # ── Confirm before replacing the live script ──────────────────────────────
    printf "  ${YELLOW}Replace ${WHITE}${_SELF}${YELLOW} with v${_NEW_VERSION}? [y/N]: ${NC}"
    read -r _CONFIRM_UPDATE
    echo ""
    if ! [[ "$_CONFIRM_UPDATE" =~ ^[Yy]$ ]]; then
        rm -f "$_TMP_FILE"
        echo -e "  ${GREEN}Update cancelled — script unchanged.${NC}"
        echo ""
        log "INFO  --update: user declined replacement"
        exit 0
    fi

    # ── Back up the current script before overwriting ─────────────────────────
    local _BACKUP="${_SELF%.sh}-v${SCRIPT_VERSION}.sh.bak"
    cp "$_SELF" "$_BACKUP" 2>/dev/null
    if [ $? -eq 0 ]; then
        printf "  ${GREEN}✓${NC} Backup saved: ${GRAY}${_BACKUP}${NC}\n"
        log "OK    --update: backup written to $_BACKUP"
    else
        printf "  ${YELLOW}⚠${NC}  Could not write backup — continuing anyway.\n"
        log "WARN  --update: backup failed"
    fi

    # ── Replace the live script ───────────────────────────────────────────────
    cp "$_TMP_FILE" "$_SELF"
    local _CP_RC=$?
    rm -f "$_TMP_FILE"

    if [ $_CP_RC -ne 0 ]; then
        echo -e "  ${RED}✗  Failed to replace script (exit $_CP_RC).${NC}"
        echo -e "  ${YELLOW}Restoring from backup...${NC}"
        [ -f "$_BACKUP" ] && cp "$_BACKUP" "$_SELF"
        log "FAIL  --update: copy failed (exit $_CP_RC); backup restored"
        exit 1
    fi

    chmod +x "$_SELF"
    log "OK    --update: script replaced with v${_NEW_VERSION}"

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}✅  Updated to version ${WHITE}${_NEW_VERSION}${GREEN}!${NC}"
    echo ""
    echo -e "  The updated script is ready. Run it again to use the new version:"
    echo -e "    ${GREEN}bash ${_SELF}${NC}"
    echo ""
    if [ -f "$_BACKUP" ]; then
        echo -e "  ${GRAY}Backup of v${SCRIPT_VERSION} : ${_BACKUP}${NC}"
        echo -e "  ${GRAY}(delete it once you confirm the new version works)${NC}"
        echo ""
    fi
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    log "=== --update done: v${SCRIPT_VERSION} → v${_NEW_VERSION} ==="
}


# =============================================================================
# ENTRY POINT — Dispatch based on the first argument
#
# (no flag)      → run full installation (main) — with pre-flight checks
# --update       → self-update this script from SCRIPT_UPDATE_URL
# --uninstall    → remove Ubuntu rootfs, cache, config, and launcher files
# --fix-vlc      → repair VLC
# --fix-firefox  → repair Firefox ESR
# --fix-code-oss → repair VS Code (code via Microsoft apt repo)
# --fix-all      → repair all three apps in sequence
# --changelog    → display version history extracted from this script's header
# --status       → report which packages, scripts, and configs are installed
# --version      → print version string and exit
# --help / -h    → print all flags and feature list, then exit
# =============================================================================
case "${1:-}" in
    --update)        update_self ;;
    --uninstall)     uninstall_senestro ;;
    --fix-vlc)       fix_vlc ;;
    --fix-firefox)   fix_firefox ;;
    --fix-code-oss)  fix_code_oss ;;
    --fix-all)       fix_all ;;
    --changelog)     show_changelog ;;
    --status)        show_status ;;
    --version)       show_version ;;
    --help|-h)       show_help ;;
    *)               main "$@" ;;
esac
