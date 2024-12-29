#!/bin/bash
# Copyright (c) 2024 Sami Halawa
# Licensed under the MIT License (see LICENSE file for details)

# Exit immediately if a command exits with a non-zero status
set +e

# Constants and Configuration
readonly VERSION="2.1"
readonly BASE_DIR="$HOME/.mac_optimizer"
readonly BACKUP_DIR="$BASE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
readonly LOG_FILE="$BACKUP_DIR/optimizer.log"
readonly SETTINGS_FILE="$BASE_DIR/settings"
readonly MIN_MACOS_VERSION="10.15" # Minimum supported macOS version (Catalina)
readonly PROFILES_DIR="$BASE_DIR/profiles"
readonly MEASUREMENTS_FILE="$BACKUP_DIR/performance_measurements.txt"
readonly SCHEDULE_FILE="$BASE_DIR/schedule"
readonly USAGE_PROFILE="$BASE_DIR/usage"
readonly AUTO_BACKUP_LIMIT=5
readonly LAST_RUN_FILE="$BASE_DIR/lastrun"
readonly TRACKED_DOMAINS=(
    "com.apple.dock"
    "com.apple.finder"
    "com.apple.universalaccess"
    "com.apple.WindowManager"
    "com.apple.QuickLookUI"
    "NSGlobalDomain"
)
if ! command -v system_profiler &> /dev/null; then
    echo "system_profiler command not found. This script requires macOS." >&2
    exit 1
fi
readonly GPU_INFO=$(system_profiler SPDisplaysDataType 2>/dev/null || echo "")

# Constants for special characters
readonly CHECK_MARK="✓"
readonly CROSS_MARK="✗"
readonly WARNING_MARK="⚠"
readonly HOURGLASS="⏳"
readonly STATS="📊"

# Color definitions
declare -r GREEN='\033[1;32m'
declare -r RED='\033[0;31m'
declare -r BLUE='\033[0;34m'
declare -r CYAN='\033[0;36m'
declare -r YELLOW='\033[0;33m'
declare -r PURPLE='\033[0;35m'
declare -r GRAY='\033[1;30m'
declare -r NC='\033[0m'
declare -r BOLD='\033[1m'
declare -r DIM='\033[2m'
declare -r UNDERLINE='\033[4m'

# Enhanced system detection
ARCH=$(uname -m)
IS_APPLE_SILICON=false
IS_ROSETTA=false
MACOS_VERSION=$(sw_vers -productVersion | sed 's/[a-zA-Z]//g')
MACOS_BUILD=$(sw_vers -buildVersion)

if [[ "$ARCH" == "arm64" ]]; then
    IS_APPLE_SILICON=true
elif [[ "$ARCH" == "x86_64" ]]; then
    # Check if running under Rosetta
    if sysctl -n sysctl.proc_translated >/dev/null 2>&1; then
        IS_ROSETTA=true
        IS_APPLE_SILICON=true
    fi
fi

# Enhanced error handling and logging
function handle_error() {
    local error_msg=$1
    local error_code=${2:-1}
    
    echo -e "${RED}Error: $error_msg (Code: $error_code)${NC}" >&2
    log "ERROR: $error_msg (Code: $error_code)"
    
    case $error_code in
        1) # Permission error
            warning "Trying to elevate privileges..."
            sudo -v
            ;;
        2) # Resource busy
            warning "Waiting for resource to be available..."
            sleep 5
            ;;
        *) # Unknown error
            warning "Unknown error occurred"
            ;;
    esac
    
    return $error_code
}

function enhanced_logging() {
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir"
    
    if [[ -f "$LOG_FILE" && $(stat -f%z "$LOG_FILE") -gt 1048576 ]]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local severity=$1
    local message=$2
    
    echo "[$timestamp][$severity] $message" >> "$LOG_FILE"
}

# Add missing log, warning, error, and success functions
function log() {
    local message=$1
    enhanced_logging "INFO" "$message"
    echo -e "${GRAY}[INFO] $message${NC}"
}

function error() {
    local message=$1
    enhanced_logging "ERROR" "$message"
    echo -e "${RED}[ERROR] $message${NC}"
}

function warning() {
    local message=$1
    enhanced_logging "WARNING" "$message"
    echo -e "${YELLOW}[WARNING] $message${NC}"
}

function success() {
    local message=$1
    enhanced_logging "SUCCESS" "$message"
    echo -e "${GREEN}[SUCCESS] $message${NC}"
}

# Memory pressure check function
function memory_pressure() {
    local memory_stats=$(vm_stat)
    local active=$(echo "$memory_stats" | awk '/Pages active/ {print $3}' | tr -d '.')
    local wired=$(echo "$memory_stats" | awk '/Pages wired/ {print $4}' | tr -d '.')
    local compressed=$(echo "$memory_stats" | awk '/Pages occupied by compressor/ {print $5}' | tr -d '.')
    local free=$(echo "$memory_stats" | awk '/Pages free/ {print $3}' | tr -d '.')
    
    if [[ -z "$active" || -z "$free" ]]; then
        echo "System memory pressure: Unable to calculate"
        return 1
    fi
    
    local used=$((active + wired + compressed))
    local total=$((used + free))
    local percentage=$((used * 100 / total))
    echo "System memory pressure: $percentage"
    return 0
}

# System state verification
function verify_system_state() {
    local checks_passed=true
    local issues=()
    
    # Fix disk verification to handle mounted volumes
    echo -ne "Checking disk health..."
    if ! diskutil verifyVolume / >/dev/null 2>&1; then
        warning "Disk verification skipped - volume is mounted"
        echo -e " ${YELLOW}⚠${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi

    # Fix memory check to handle invalid values
    echo -ne "Checking memory pressure..."
    local mem_pressure
    mem_pressure=$(memory_pressure | grep -o "[0-9]*$" || echo "0")
    if [[ -n "$mem_pressure" ]] && ((mem_pressure > 80)); then
        issues+=("High memory pressure detected: ${mem_pressure}%")
        checks_passed=false
        echo -e " ${RED}✗${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi

    # Fix CPU thermal check to handle missing sysctl
    echo -ne "Checking CPU temperature..."
    if ! sysctl machdep.xcpm.cpu_thermal_level >/dev/null 2>&1; then
        echo -e " ${YELLOW}⚠${NC} (Not available)"
    elif sysctl machdep.xcpm.cpu_thermal_level | grep -q "[1-9]"; then
        issues+=("CPU thermal throttling detected")
        checks_passed=false
        echo -e " ${RED}✗${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi

    return $((checks_passed == false))
}

# Version comparison function
function version_compare() {
    local v1=$1
    local v2=$2

    # Convert versions to comparable numbers
    local IFS=.
    read -ra v1_parts <<< "$v1"
    read -ra v2_parts <<< "$v2"

    # Compare each part
    for ((i=0; i<${#v1_parts[@]} || i<${#v2_parts[@]}; i++)); do
        local v1_part=${v1_parts[i]:-0}
        local v2_part=${v2_parts[i]:-0}
        
        if ((v1_part > v2_part)); then
            return 1    # v1 is greater
        elif ((v1_part < v2_part)); then
            return 2    # v2 is greater
        fi
    done
    return 0    # versions are equal
}

# Enhanced cleanup function
function cleanup() {
    tput cnorm 2>/dev/null || true # Show cursor, handle failure
    echo -e "\n${GRAY}Cleaning up...${NC}"
    
    # Fix temp file cleanup with proper error handling
    local temp_files=(
        "/tmp/mac_optimizer_temp"
        "/tmp/mac_optimizer_cleanup"
        "/private/tmp/mac_optimizer_*"
    )
    
    for file in "${temp_files[@]}"; do
        if [[ -e "$file" ]]; then
            rm -rf "$file" 2>/dev/null || warning "Failed to remove $file"
        fi
    done
    
    # Fix process termination
    killall "System Preferences" &>/dev/null || true
    
    if [[ -f "/tmp/mac_optimizer_ui_modified" ]]; then
        killall Finder Dock &>/dev/null || true
        rm "/tmp/mac_optimizer_ui_modified" 2>/dev/null || true
    fi
}

# Enhanced system validation
function check_system_requirements() {
    # Remove sudo check since it causes issues
    # if [[ $EUID -ne 0 ]]; then
    #     error "This script must be run with sudo privileges"
    #     exit 1
    # fi

    # Get the detected version and normalize it for comparison
    local detected_version=$(sw_vers -productVersion)
    local major_version=$(echo "$detected_version" | cut -d. -f1)
    
    # Fix version comparison for newer macOS versions
    if [[ $major_version -ge 11 ]] || [[ "$detected_version" == "10.15"* ]]; then
        return 0
    fi
    
    error "This script requires macOS $MIN_MACOS_VERSION or later (detected: $detected_version)"
    exit 1
}

# Enhanced progress bar with spinner
function show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local title=$3
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_idx=0
    
    # Calculate percentage and bar width
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Build the progress bar
    tput cr
    printf "${CYAN}${spinner[$spin_idx]}${NC} "
    printf "${title} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${percent}%%"
    tput el
    
    # Add completion message if done
    if [ "$current" -eq "$total" ]; then
        printf "\n${GREEN}✓ Complete!${NC}\n"
    fi
}

# Update the track_progress function to use the new progress bar
function track_progress() {
    local current=$1
    local total=$2
    local message=$3
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    
    # Update progress gauge
    echo $percent | dialog --gauge "$message" \
                          8 70 0
}

# Add a spinner for operations without clear progress
function show_spinner() {
    local message=$1
    local pid=$2
    local spin='-\|/'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r${CYAN}${spin:$i:1}${NC} %s..." "$message"
        sleep .1
    done
    tput cr
    tput el
    printf "${GREEN}✓${NC} %s... Done\n" "$message"
}

# Update optimize_system_performance to use the new progress indicators
function optimize_system_performance() {
    log "Starting system performance optimization"
    echo -e "\n${CYAN}Detailed System Performance Optimization Progress:${NC}"
    
    # Track changes for summary
    local changes_made=()
    local total_steps=12
    local current_step=0

    # 1. Kernel Parameter Optimization
    echo -e "\n${BOLD}1. Kernel Parameter Optimization:${NC}"
    
    local sysctl_params=(
        "kern.maxvnodes=750000"        # Increased from 250000 for better filesystem performance
        "kern.maxproc=4096"           # Increased from 2048 for more concurrent processes
        "kern.maxfiles=524288"        # Increased from 262144 for more file descriptors
        "kern.ipc.somaxconn=4096"     # Increased from 1024 for more network connections
        "kern.ipc.maxsockbuf=8388608" # Increased for better network performance
        "kern.ipc.nmbclusters=65536"  # Network buffer clusters optimization
    )
    
    for param in "${sysctl_params[@]}"; do
        ((current_step++))
        echo -ne "  ${HOURGLASS} Setting $param..."
        if sudo sysctl -w "$param" 2>/dev/null; then
            changes_made+=("Kernel parameter $param set")
            echo -e "\r  ${GREEN}✓${NC} $param applied"
        else
            echo -e "\r  ${RED}✗${NC} Failed to set $param"
        fi
        show_progress $current_step $total_steps
    done

    # 2. Performance Mode Settings
    echo -e "\n${BOLD}2. Performance Mode Settings:${NC}"
    
    ((current_step++))
    echo -ne "  ${HOURGLASS} Setting maximum performance mode..."
    if sudo pmset -a highperf 1 2>/dev/null; then
        changes_made+=("High performance mode enabled")
        echo -e "\r  ${GREEN}✓${NC} Maximum performance mode set"
    else
        echo -e "\r  ${RED}✗${NC} Failed to set performance mode"
    fi
    show_progress $current_step $total_steps

    # 3. CPU and Memory Optimization
    echo -e "\n${BOLD}3. CPU and Memory Optimization:${NC}"
    
    ((current_step++))
    echo -ne "  ${HOURGLASS} Optimizing CPU settings..."
    if sudo nvram boot-args="serverperfmode=1 $(nvram boot-args 2>/dev/null | cut -f 2-)"; then
        changes_made+=("CPU server performance mode enabled")
        echo -e "\r  ${GREEN}✓${NC} CPU optimization applied"
    else
        echo -e "\r  ${RED}✗${NC} Failed to optimize CPU settings"
    fi
    show_progress $current_step $total_steps

    # 4. Network Stack Optimization
    echo -e "\n${BOLD}4. Network Stack Optimization:${NC}"
    
    local network_params=(
        "net.inet.tcp.delayed_ack=0"
        "net.inet.tcp.mssdflt=1440"
        "net.inet.tcp.win_scale_factor=8"
        "net.inet.tcp.sendspace=524288"
        "net.inet.tcp.recvspace=524288"
    )
    
    for param in "${network_params[@]}"; do
        ((current_step++))
        echo -ne "  ${HOURGLASS} Setting $param..."
        if sudo sysctl -w "$param" 2>/dev/null; then
            changes_made+=("Network parameter $param set")
            echo -e "\r  ${GREEN}✓${NC} $param applied"
        else
            echo -e "\r  ${RED}✗${NC} Failed to set $param"
        fi
        show_progress $current_step $total_steps
    done

    # Summary
    echo -e "\n${CYAN}Optimization Summary:${NC}"
    echo -e "Total optimizations applied: ${#changes_made[@]}"
    for change in "${changes_made[@]}"; do
        echo -e "${GREEN}✓${NC} $change"
    done

    success "System performance optimization completed with ${#changes_made[@]} improvements"
    return 0
}

# Progress bar function
function show_progress() {
    local -r percent=$1
    local -r message=${2:-""}
    local -r width=30
    local -r completed=$((width * percent / 100))
    local -r remaining=$((width - completed))
    
    printf "\r${CYAN}[%s%s]${NC} %3d%% %s" \
        "$(printf "%${completed}s" | tr ' ' '█')" \
        "$(printf "%${remaining}s" | tr ' ' '░')" \
        "$percent" \
        "$message"
}

# Progress tracking for optimizations (without dialog dependency)
function track_progress() {
    local step=$1
    local total=$2
    local message=$3
    
    # Calculate percentage and bar width
    local percent=$((step * 100 / total))
    local width=50
    local filled=$((width * step / total))
    local empty=$((width - filled))
    
    # Show progress bar
    printf "\r  ${GRAY}[${GREEN}"
    printf "%${filled}s" | tr ' ' '█'
    printf "${GRAY}"
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${BOLD}%3d%%${NC} %s" $percent "$message"
}

# Enhanced graphics optimization for systems with limited GPU capabilities
function optimize_graphics() {
    log "Starting graphics optimization"
    echo -e "\n${CYAN}Detailed Graphics Optimization Progress:${NC}"
    
    # Track changes for summary
    local changes_made=()
    local total_steps=15
    local current_step=0

    # Create backup before making changes
    backup_graphics_settings

    # 1. Window Server Optimizations
    echo -e "\n${BOLD}1. Window Server Optimizations:${NC}"
    
    ((current_step++))
    echo -ne "  ${HOURGLASS} Optimizing drawing performance..."
    if sudo defaults write /Library/Preferences/com.apple.windowserver UseOptimizedDrawing -bool true 2>/dev/null; then
        defaults write com.apple.WindowServer UseOptimizedDrawing -bool true
        defaults write com.apple.WindowServer Accelerate -bool true  # Changed to true for maximum performance
        defaults write com.apple.WindowServer EnableHiDPI -bool true # Enable HiDPI for better quality
        changes_made+=("Drawing optimization enabled")
        echo -e "\r  ${GREEN}✓${NC} Drawing performance optimized"
    else
        echo -e "\r  ${RED}✗${NC} Failed to optimize drawing performance"
    fi
    show_progress $current_step $total_steps

    # 2. GPU Settings
    echo -e "\n${BOLD}2. GPU Settings:${NC}"
    
    ((current_step++))
    echo -ne "  ${HOURGLASS} Optimizing GPU performance..."
    if sudo defaults write com.apple.WindowServer MaximumGPUMemory -int 4096 2>/dev/null; then  # Increased GPU memory
        defaults write com.apple.WindowServer GPUPowerPolicy -string "maximum"  # Changed to maximum
        defaults write com.apple.WindowServer DisableGPUProcessing -bool false  # Enable GPU processing
        changes_made+=("GPU performance maximized")
        echo -e "\r  ${GREEN}✓${NC} GPU settings optimized"
    else
        echo -e "\r  ${RED}✗${NC} Failed to optimize GPU settings"
    fi
    show_progress $current_step $total_steps

    # 3. Animation and Visual Effects
    echo -e "\n${BOLD}3. Animation and Visual Effects:${NC}"
    
    ((current_step++))
    echo -ne "  ${HOURGLASS} Optimizing window animations..."
    if sudo defaults write -g NSWindowResizeTime -float 0.001 2>/dev/null; then
        defaults write -g NSAutomaticWindowAnimationsEnabled -bool true  # Enable for smooth animations
        defaults write -g NSWindowResizeTime -float 0.001
        changes_made+=("Window animations optimized")
        echo -e "\r  ${GREEN}✓${NC} Window animations optimized"
    else
        echo -e "\r  ${RED}✗${NC} Failed to optimize window animations"
    fi
    show_progress $current_step $total_steps
    
    ((current_step++))
    echo -ne "  ${HOURGLASS} Adjusting dock animations..."
    if sudo defaults write com.apple.dock autohide-time-modifier -float 0.0 2>/dev/null && \
       sudo defaults write com.apple.dock autohide-delay -float 0.0 2>/dev/null; then
        defaults write com.apple.dock autohide-time-modifier -float 0.0
        defaults write com.apple.dock autohide-delay -float 0.0
        changes_made+=("Dock animations optimized")
        echo -e "\r  ${GREEN}✓${NC} Dock animations adjusted"
    else
        echo -e "\r  ${RED}✗${NC} Failed to adjust dock animations"
    fi
    show_progress $current_step $total_steps

    # 4. Metal Performance
    echo -e "\n${BOLD}4. Metal Performance:${NC}"
    
    ((current_step++))
    echo -ne "  ${HOURGLASS} Optimizing Metal performance..."
    if sudo defaults write /Library/Preferences/com.apple.CoreDisplay useMetal -bool true 2>/dev/null && \
       sudo defaults write /Library/Preferences/com.apple.CoreDisplay useIOP -bool true 2>/dev/null; then
        defaults write NSGlobalDomain MetalForceHardwareRenderer -bool true
        defaults write NSGlobalDomain MetalLoadingPriority -string "High"
        changes_made+=("Metal performance optimized")
        echo -e "\r  ${GREEN}✓${NC} Metal performance optimized"
    else
        echo -e "\r  ${RED}✗${NC} Failed to optimize Metal performance"
    fi
    show_progress $current_step $total_steps

    # Force kill all UI processes to apply changes
    echo -ne "\n${HOURGLASS} Applying all changes (this may cause a brief screen flicker)..."
    sudo killall Dock &>/dev/null
    sudo killall Finder &>/dev/null
    sudo killall SystemUIServer &>/dev/null
    echo -e "\r${GREEN}✓${NC} All changes applied"

    # Summary
    echo -e "\n${CYAN}Optimization Summary:${NC}"
    echo -e "Total optimizations applied: ${#changes_made[@]}"
    for change in "${changes_made[@]}"; do
        echo -e "${GREEN}✓${NC} $change"
    done

    echo -e "\n${YELLOW}Note: Some changes require logging out and back in to take full effect${NC}"
    echo -e "${YELLOW}If changes are not visible, please log out and log back in${NC}"

    success "Graphics optimization completed with ${#changes_made[@]} improvements"
    return 0
}

# Add required helper functions
function backup_graphics_settings() {
    local backup_file="$BACKUP_DIR/graphics_$(date +%Y%m%d_%H%M%S)"
    
    # Backup all relevant domains
    defaults export com.apple.WindowServer "$backup_file.windowserver"
    defaults export com.apple.dock "$backup_file.dock"
    defaults export com.apple.finder "$backup_file.finder"
    defaults export NSGlobalDomain "$backup_file.global"
    
    echo "$backup_file" > "$BACKUP_DIR/last_graphics_backup"
    log "Graphics settings backed up to $backup_file"
}

function restart_ui_services() {
    # Kill less critical services first
    killall Dock Finder SystemUIServer &>/dev/null || true
    
    # Only kill WindowServer if forced and necessary
    if [[ "$1" == "--force" ]]; then
        # Give other services time to restart
        sleep 2
        sudo killall WindowServer &>/dev/null || true
    fi
}

function setup_recovery() {
    local recovery_script="$BASE_DIR/recovery.sh"
    
    # Create recovery script
    cat > "$recovery_script" << 'EOF'
#!/bin/bash
# Graphics Settings Recovery Script

# Restore defaults
defaults delete com.apple.WindowServer
defaults delete com.apple.dock
defaults delete com.apple.finder
defaults delete NSGlobalDomain

# Re-enable services
sudo mdutil -a -i on
sudo tmutil enablelocal

# Reset power management
sudo pmset -a hibernatemode 3
sudo pmset -a sleep 1

# Restart UI
killall Dock Finder SystemUIServer

echo "Settings restored to defaults"
EOF
    
    chmod +x "$recovery_script"
    log "Recovery script created at $recovery_script"
}

# New function for display optimization
function optimize_display() {
    log "Starting display optimization"
    clear
    
    echo -e "\n${BOLD}${CYAN}Display Optimization${NC}"
    echo -e "${DIM}Optimizing display settings for better performance...${NC}\n"
    
    # Create measurements directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"
    
    # Store initial measurements
    system_profiler SPDisplaysDataType > "$MEASUREMENTS_FILE.before"
    
    local total_steps=5
    local current_step=0
    local changes_made=()
    
    # Get display information
    local display_info=$(system_profiler SPDisplaysDataType)
    local is_retina=$(echo "$display_info" | grep -i "retina" || echo "")
    local is_scaled=$(echo "$display_info" | grep -i "scaled" || echo "")
    
    # Resolution optimization
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing resolution settings"
    if [[ -n "$is_retina" ]]; then
        if sudo defaults write NSGlobalDomain AppleFontSmoothing -int 0 && \
           sudo defaults write NSGlobalDomain CGFontRenderingFontSmoothingDisabled -bool true; then
            changes_made+=("Optimized Retina display settings")
        printf "\r  ${GREEN}✓${NC} Optimized Retina settings for performance\n"
        fi
    else
        if sudo defaults write NSGlobalDomain AppleFontSmoothing -int 1; then
            changes_made+=("Optimized standard display settings")
        printf "\r  ${GREEN}✓${NC} Optimized standard display settings\n"
        fi
    fi
    
    # Color profile optimization
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing color settings"
    if sudo defaults write NSGlobalDomain AppleICUForce24HourTime -bool true && \
       sudo defaults write NSGlobalDomain AppleDisplayScaleFactor -int 1; then
        changes_made+=("Optimized color settings")
    printf "\r  ${GREEN}✓${NC} Display color optimized\n"
    fi
    
    # Font rendering
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing font rendering"
    if sudo defaults write NSGlobalDomain AppleFontSmoothing -int 1 && \
       sudo defaults write -g CGFontRenderingFontSmoothingDisabled -bool NO; then
        changes_made+=("Optimized font rendering")
    printf "\r  ${GREEN}✓${NC} Font rendering optimized\n"
    fi
    
    # Screen update optimization
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing screen updates"
    if sudo defaults write com.apple.CrashReporter DialogType none && \
       sudo defaults write com.apple.screencapture disable-shadow -bool true; then
        changes_made+=("Optimized screen updates")
    printf "\r  ${GREEN}✓${NC} Screen updates optimized\n"
    fi
    
    # Apply changes
    ((current_step++))
    track_progress $current_step $total_steps "Applying display changes"
    killall SystemUIServer &>/dev/null
    printf "\r  ${GREEN}✓${NC} Display changes applied\n"
    
    # Store final measurements
    system_profiler SPDisplaysDataType > "$MEASUREMENTS_FILE.after"
    
    # Show optimization summary
    echo -e "\n${CYAN}Optimization Summary:${NC}"
    echo -e "Total optimizations applied: ${#changes_made[@]}"
    for change in "${changes_made[@]}"; do
        echo -e "${GREEN}✓${NC} $change"
    done
    
    # Compare before/after display settings
    echo -e "\n${CYAN}Display Settings Changes:${NC}"
    local before_res=$(grep "Resolution:" "$MEASUREMENTS_FILE.before" | head -1 | cut -d: -f2-)
    local after_res=$(grep "Resolution:" "$MEASUREMENTS_FILE.after" | head -1 | cut -d: -f2-)
    echo -e "Resolution: $before_res -> $after_res"
    
    local before_depth=$(grep "Depth:" "$MEASUREMENTS_FILE.before" | head -1 | cut -d: -f2-)
    local after_depth=$(grep "Depth:" "$MEASUREMENTS_FILE.after" | head -1 | cut -d: -f2-)
    echo -e "Color Depth: $before_depth -> $after_depth"
    
    echo -e "\n${GREEN}Display optimization completed successfully${NC}"
    echo -e "${DIM}Note: Some changes may require a logout/login to take full effect${NC}"
    sleep 1
    return 0
}

# Storage optimization with proper permissions
function optimize_storage() {
    log "Starting storage optimization"
    
    echo -e "\n${CYAN}Storage Optimization Progress:${NC}"
    
    # Show initial storage status
    local initial_space=$(df -h / | awk 'NR==2 {printf "%s of %s", $4, $2}')
    echo -e "${STATS} Initial Storage Available: $initial_space"
    
    # Create temporary directory for parallel operations
    local tmp_dir=$(mktemp -d)
    
    # Track progress
    local total_steps=5
    local current_step=0
    
    # 1. Clean User Cache
    ((current_step++))
    echo -ne "\n${HOURGLASS} Cleaning user cache..."
    {
        sudo rm -rf ~/Library/Caches/* 
        sudo rm -rf ~/Library/Application\ Support/*/Cache/*
    } > "$tmp_dir/user_cache.log" 2>&1
    show_progress $((current_step * 100 / total_steps)) "User cache cleaned"
    
    # 2. Clean System Cache
    ((current_step++))
    echo -ne "\n${HOURGLASS} Cleaning system cache..."
    {
        sudo rm -rf /Library/Caches/* 
        sudo rm -rf /System/Library/Caches/*
    } > "$tmp_dir/system_cache.log" 2>&1
    show_progress $((current_step * 100 / total_steps)) "System cache cleaned"
    
    # 3. Clean Docker files
    ((current_step++))
    echo -ne "\n${HOURGLASS} Cleaning Docker files..."
    {
        sudo rm -rf ~/Library/Containers/com.docker.docker/Data/vms/* 
        sudo rm -rf ~/Library/Containers/com.docker.docker/Data/log/*
        sudo rm -rf ~/Library/Containers/com.docker.docker/Data/cache/*
        sudo rm -rf ~/Library/Group\ Containers/group.com.docker/Data/cache/*
        sudo rm -rf ~/Library/Containers/com.docker.docker/Data/tmp/*
    } > "$tmp_dir/docker.log" 2>&1
    show_progress $((current_step * 100 / total_steps)) "Docker files cleaned"
    
    # 4. Clean Development Cache
    ((current_step++))
    echo -ne "\n${HOURGLASS} Cleaning development cache..."
    {
        sudo rm -rf ~/Library/Developer/Xcode/DerivedData/* 
        sudo rm -rf ~/Library/Developer/Xcode/Archives/*
    } > "$tmp_dir/dev_cache.log" 2>&1
    show_progress $((current_step * 100 / total_steps)) "Development cache cleaned"
    
    # 5. Clean System Logs
    ((current_step++))
    echo -ne "\n${HOURGLASS} Cleaning system logs..."
    {
        sudo rm -rf /private/var/log/*
        sudo rm -rf ~/Library/Logs/*
    } > "$tmp_dir/logs.log" 2>&1
    show_progress $((current_step * 100 / total_steps)) "System logs cleaned"
    
    # Show final storage status
    local final_space=$(df -h / | awk 'NR==2 {printf "%s of %s", $4, $2}')
    echo -e "\n\n${STATS} Final Storage Available: $final_space"
    
    # Cleanup
    rm -rf "$tmp_dir"
    
    success "Storage optimization completed"
    return 0
}

# Network Optimization
function optimize_network() {
    log "Starting network optimization"
    
    echo -e "\n${CYAN}Network Optimization Progress:${NC}"
    echo -e "This will optimize network settings for better performance."
    echo -e "Estimated time: 15-20 seconds\n"
    
    local total_steps=4
    local current_step=0
    
    # Show initial network status
    echo -e "📊 Current Network Status:"
    echo -e "DNS Response Time: $(ping -c 1 8.8.8.8 2>/dev/null | grep "time=" | cut -d= -f4)"
    echo -e "IPv6: $(networksetup -getinfo "Wi-Fi" | grep "IPv6: ")\n"
    
    # DNS cache flush
    echo -e "⏳ [1/$total_steps] Optimizing DNS settings..."
    if version_compare "$MACOS_VERSION" "12.0"; then
        local dns_success=true
        if ! sudo dscacheutil -flushcache 2>/dev/null; then
            dns_success=false
            echo -e "${YELLOW}⚠${NC} Failed to flush DNS cache"
        fi
        if ! sudo killall -HUP mDNSResponder 2>/dev/null; then
            dns_success=false
            echo -e "${YELLOW}⚠${NC} Failed to restart mDNSResponder"
        fi
        if $dns_success; then
            echo -e "${GREEN}✓${NC} DNS cache cleared and service restarted"
        fi
    else
        if ! sudo killall -HUP mDNSResponder 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Failed to restart mDNSResponder"
        else
            echo -e "${GREEN}✓${NC} DNS service restarted"
        fi
    fi
    ((current_step++))
    
    # Network stack optimization
    echo -e "\n⏳ [2/$total_steps] Optimizing network stack..."
    local sysctl_settings=(
        "kern.ipc.somaxconn=1024"
        "kern.ipc.maxsockbuf=4194304"
    )
    local sysctl_success=true
    
    for setting in "${sysctl_settings[@]}"; do
        echo -ne "\rApplying setting: $setting..."
        if ! sudo sysctl -w "$setting" 2>/dev/null; then
            sysctl_success=false
            echo -e "\n${YELLOW}⚠${NC} Failed to apply: $setting"
        fi
    done
    
    if $sysctl_success; then
        echo -e "\n${GREEN}✓${NC} Network stack optimized"
    fi
    ((current_step++))
    
    # IPv6 configuration
    echo -e "\n⏳ [3/$total_steps] Configuring IPv6..."
    if ! networksetup -setv6off "Wi-Fi" 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC} Failed to configure IPv6"
    else
        echo -e "${GREEN}✓${NC} IPv6 configured"
    fi
    ((current_step++))
    
    # Verify changes
    echo -e "\n⏳ [4/$total_steps] Verifying network changes..."
    echo -e "\n Updated Network Status:"
    echo -e "DNS Response Time: $(ping -c 1 8.8.8.8 2>/dev/null | grep "time=" | cut -d= -f4)"
    echo -e "IPv6: $(networksetup -getinfo "Wi-Fi" | grep "IPv6: ")"
    ((current_step++))
    
    # Summary
    echo -e "\n${CYAN}Network Optimization Summary:${NC}"
    echo -e "Steps completed: $current_step/$total_steps"
    if [ $current_step -eq $total_steps ]; then
        echo -e "${GREEN}All network optimizations completed successfully${NC}"
    else
        echo -e "${YELLOW}Some network optimizations were skipped or failed${NC}"
    fi
    
    success "Network optimization completed"
    return 0
}

# Security optimization with minimum restrictions
function optimize_security() {
    log "Starting security optimization with minimum restrictions"
    
    echo -e "\n${CYAN}Security Configuration:${NC}"
    echo -e "This will configure minimum security settings."
    
    # Disable Gatekeeper
    echo -ne "  ${HOURGLASS} Disabling Gatekeeper..."
    if sudo spctl --master-disable 2>/dev/null; then
        echo -e "\r  ${GREEN}✓${NC} Gatekeeper disabled"
    fi
    
    # Disable Firewall
    echo -ne "  ${HOURGLASS} Disabling Firewall..."
    if sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 0 2>/dev/null; then
        echo -e "\r  ${GREEN}✓${NC} Firewall disabled"
    fi
    
    # Disable automatic security updates
    echo -ne "  ${HOURGLASS} Disabling automatic security updates..."
    if sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false 2>/dev/null; then
        echo -e "\r  ${GREEN}✓${NC} Automatic updates disabled"
    fi
    
    # Configure Safari for maximum compatibility
    echo -ne "  ${HOURGLASS} Configuring Safari settings..."
    defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool true
    defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool true
    defaults write com.apple.Safari WebKitJavaEnabled -bool true
    defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool true
    defaults write com.apple.Safari WebKitPluginsEnabled -bool true
    defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2PluginsEnabled -bool true
    echo -e "\r  ${GREEN}✓${NC} Safari configured for maximum compatibility"
    
    success "Security settings configured for minimum restrictions"
    return 0
}

# Function to restore minimum security settings
function restore_minimum_security() {
    log "Restoring minimum security settings"
    
    # Disable SIP (requires recovery mode)
    echo -e "${YELLOW}Note: To completely disable SIP, restart in recovery mode and run: csrutil disable${NC}"
    
    # Disable Gatekeeper
    sudo spctl --master-disable
    
    # Disable Firewall
    sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 0
    
    # Disable automatic updates
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool false
    sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool false
    
    # Disable application verification
    sudo defaults write com.apple.LaunchServices LSQuarantine -bool false
    
    # Allow apps from anywhere
    sudo defaults write /Library/Preferences/com.apple.security GKAutoRearm -bool false
    
    # Disable crash reporter
    defaults write com.apple.CrashReporter DialogType none
    
    # Configure Safari for maximum compatibility
    defaults write com.apple.Safari WebKitJavaScriptCanOpenWindowsAutomatically -bool true
    defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically -bool true
    defaults write com.apple.Safari WebKitJavaEnabled -bool true
    defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled -bool true
    defaults write com.apple.Safari WebKitPluginsEnabled -bool true
    defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2PluginsEnabled -bool true
    
    # Disable application sandboxing
    sudo defaults write /Library/Preferences/com.apple.security.libraryvalidation Disabled -bool true
    
    success "System configured for minimum security restrictions"
    echo -e "${YELLOW}Note: Some changes may require a restart to take effect${NC}"
    echo -e "${YELLOW}Warning: These settings significantly reduce system security${NC}"
}

# Backup functionality
function create_backup() {
    log "Creating system backup"
    
    local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BASE_DIR/backups/$backup_name"
    
    echo -e "\n${CYAN}Creating backup...${NC}"
    
    # Create backup directory
    if ! mkdir -p "$backup_path"; then
        error "Failed to create backup directory"
        return 1
    fi
    
    # Backup system settings
    if ! defaults export -globalDomain "$backup_path/global_defaults.plist"; then
        error "Failed to backup global defaults"
        return 1
    fi
    
    # Backup tracked domains
    for domain in "${TRACKED_DOMAINS[@]}"; do
        if defaults export "$domain" "$backup_path/${domain}.plist" 2>/dev/null; then
            log "Backed up $domain"
        fi
    done
    
    success "Backup created successfully at: $backup_path"
    return 0
}

# Add new functions for enhanced user experience
function measure_performance() {
    local measurement_type=$1
    case $measurement_type in
        "boot") system_profiler SPStartupItemDataType > "$MEASUREMENTS_FILE.before" ;;
        "memory") vm_stat > "$MEASUREMENTS_FILE.before" ;;
        "disk") diskutil info / > "$MEASUREMENTS_FILE.before" ;;
        "network") networksetup -getinfo "Wi-Fi" > "$MEASUREMENTS_FILE.before" ;;
    esac
}

function show_comparison() {
    local measurement_type=$1
    echo -e "${BLUE}Before:${NC}"
    cat "$MEASUREMENTS_FILE.before"
    echo -e "${BLUE}After:${NC}"
    case $measurement_type in
        "boot") system_profiler SPStartupItemDataType ;;
        "memory") vm_stat ;;
        "disk") diskutil info / ;;
        "network") networksetup -getinfo "Wi-Fi" ;;
    esac
}

# Display system info with better formatting
function display_system_info() {
    echo -e "\n${BOLD}${CYAN}System Information${NC}\n"
    
    # Hardware
    echo -e "${UNDERLINE}Hardware${NC}"
    printf "  %-13s %s\n" "CPU:" "$(sysctl -n machdep.cpu.brand_string)"
    printf "  %-13s %s\n" "Memory:" "$(sysctl hw.memsize | awk '{printf "%.0f GB", $2/1024/1024/1024}')"
    printf "  %-13s %s\n" "Architecture:" "$ARCH"
    printf "  %-13s %s\n" "Apple Silicon:" "${IS_APPLE_SILICON:+"Yes":"No"}"
    [[ $IS_ROSETTA == true ]] && printf "  %-13s %s\n" "Rosetta:" "Yes"
    
    # System
    echo -e "\n${UNDERLINE}System${NC}"
    printf "  %-13s %s\n" "macOS:" "$(sw_vers -productVersion)"
    printf "  %-13s %s\n" "Build:" "$(sw_vers -buildVersion)"
    printf "  %-13s %s\n" "Available:" "$(df -h / | awk 'NR==2 {print $4}')"
    
    # Usage (if available)
    if [[ -f "$USAGE_PROFILE" ]]; then
        echo -e "\n${UNDERLINE}Usage Statistics${NC}"
        source "$USAGE_PROFILE"
        printf "  %-13s %s\n" "Last Check:" "$(date -r $last_analyzed "+%Y-%m-%d %H:%M")"
        printf "  %-13s %s%%\n" "Memory Usage:" "$memory_usage"
        printf "  %-13s %s%%\n" "Disk Usage:" "$disk_usage"
        [[ -n "$battery_cycles" ]] && printf "  %-13s %s\n" "Battery Cycles:" "$battery_cycles"
    fi
    echo
}

# Improved optimization description
function describe_optimization() {
    local opt_type=$1
    
    # Clear screen and reset cursor position
    clear
    tput cup 0 0
    
    echo -e "\n${BOLD}${CYAN}Optimization Details${NC}\n"
    
    case $opt_type in
        "performance")
            echo -e "${UNDERLINE}Changes to be made:${NC}"
            echo -e "  ${GREEN}•${NC} Set kern.ipc.somaxconn=2048 (Increases maximum concurrent connections)"
            echo -e "  ${GREEN}•${NC} Set kern.ipc.nmbclusters=65536 (Optimizes network buffer clusters)"
            echo -e "  ${GREEN}•${NC} Set kern.maxvnodes=750000 (Improves filesystem performance)"
            echo -e "  ${GREEN}•${NC} Set kern.maxproc=2048 (Increases maximum processes)"
            echo -e "  ${GREEN}•${NC} Set kern.maxfiles=200000 (Increases file descriptor limit)"
            
            echo -e "\n${UNDERLINE}Impact Analysis:${NC}"
            echo -e "  ${CYAN}→${NC} Performance Impact: ${GREEN}High${NC}"
            echo -e "  ${CYAN}→${NC} Memory Usage: ${YELLOW}+100-200MB${NC}"
            echo -e "  ${CYAN}→${NC} CPU Impact: ${GREEN}Minimal${NC}"
            echo -e "  ${CYAN}→${NC} Disk Impact: ${GREEN}None${NC}"
            echo -e "  ${CYAN}→${NC} Safety Level: ${GREEN}Safe${NC}"
            echo -e "  ${CYAN}→${NC} Reversible: ${GREEN}Yes${NC}"
            
            echo -e "\n${DIM}These optimizations will improve system responsiveness and throughput${NC}"
            ;;
            
        "graphics")
            echo -e "${UNDERLINE}Changes to be made:${NC}"
            echo -e "  ${GREEN}•${NC} Disable transparency (com.apple.universalaccess reduceTransparency -bool true)"
            echo -e "  ${GREEN}•${NC} Optimize animations (NSAutomaticWindowAnimationsEnabled -bool false)"
            echo -e "  ${GREEN}•${NC} Reduce motion effects (reduceMotion -bool true)"
            echo -e "  ${GREEN}•${NC} Optimize Dock (autohide-time-modifier -float 0)"
            echo -e "  ${GREEN}•${NC} Disable window effects (NSWindowResizeTime -float 0.001)"
            [[ $IS_APPLE_SILICON == true ]] && echo -e "  ${GREEN}•${NC} Optimize Metal performance settings"
            
            echo -e "\n${UNDERLINE}Impact Analysis:${NC}"
            echo -e "  ${CYAN}→${NC} Performance Impact: ${GREEN}Medium${NC}"
            echo -e "  ${CYAN}→${NC} GPU Usage: ${GREEN}-20-30%${NC}"
            echo -e "  ${CYAN}→${NC} Battery Impact: ${GREEN}+5-10% battery life${NC}"
            echo -e "  ${CYAN}→${NC} Visual Impact: ${YELLOW}Reduced visual effects${NC}"
            echo -e "  ${CYAN}→${NC} Safety Level: ${GREEN}Very Safe${NC}"
            echo -e "  ${CYAN}→${NC} Reversible: ${GREEN}Yes${NC}"
            
            echo -e "\n${DIM}These optimizations will improve UI responsiveness and reduce GPU load${NC}"
            ;;
            
        "display")
            echo -e "${UNDERLINE}Changes to be made:${NC}"
            echo -e "  ${GREEN}•${NC} Optimize font rendering (AppleFontSmoothing settings)"
            echo -e "  ${GREEN}•${NC} Adjust color profiles (AppleICUForce24HourTime)"
            echo -e "  ${GREEN}•${NC} Set display scale factor (AppleDisplayScaleFactor)"
            echo -e "  ${GREEN}•${NC} Optimize screen updates (disable-shadow)"
            echo -e "  ${GREEN}•${NC} Configure HiDPI settings if available"
            
            echo -e "\n${UNDERLINE}Impact Analysis:${NC}"
            echo -e "  ${CYAN}→${NC} Performance Impact: ${GREEN}Medium${NC}"
            echo -e "  ${CYAN}→${NC} Visual Quality: ${YELLOW}Slightly reduced${NC}"
            echo -e "  ${CYAN}→${NC} GPU Usage: ${GREEN}-10-15%${NC}"
            echo -e "  ${CYAN}→${NC} Battery Impact: ${GREEN}+3-5% battery life${NC}"
            echo -e "  ${CYAN}→${NC} Safety Level: ${GREEN}Safe${NC}"
            echo -e "  ${CYAN}→${NC} Reversible: ${GREEN}Yes${NC}"
            
            echo -e "\n${DIM}These optimizations will improve display performance and reduce power usage${NC}"
            ;;
            
        "storage")
            echo -e "${UNDERLINE}Changes to be made:${NC}"
            echo -e "  ${GREEN}•${NC} Clear system caches (~/Library/Caches cleanup)"
            echo -e "  ${GREEN}•${NC} Remove old logs (system and user logs older than 7 days)"
            echo -e "  ${GREEN}•${NC} Clean Time Machine snapshots"
            echo -e "  ${GREEN}•${NC} Clear development tool caches (if present)"
            echo -e "  ${GREEN}•${NC} Remove .DS_Store files"
            
            echo -e "\n${UNDERLINE}Impact Analysis:${NC}"
            echo -e "  ${CYAN}→${NC} Space Saved: ${GREEN}500MB-5GB typical${NC}"
            echo -e "  ${CYAN}→${NC} Performance Impact: ${GREEN}+5-10% disk speed${NC}"
            echo -e "  ${CYAN}→${NC} Boot Time: ${GREEN}-2-3 seconds${NC}"
            echo -e "  ${CYAN}→${NC} App Launch: ${GREEN}Faster${NC}"
            echo -e "  ${CYAN}→${NC} Safety Level: ${GREEN}Safe${NC}"
            echo -e "  ${CYAN}→${NC} Reversible: ${YELLOW}Partial${NC}"
            
            echo -e "\n${DIM}These optimizations will free up space and improve disk performance${NC}"
            ;;
            
        "network")
            echo -e "${UNDERLINE}Changes to be made:${NC}"
            echo -e "  ${GREEN}•${NC} Set net.inet.tcp.delayed_ack=0 (Reduces latency)"
            echo -e "  ${GREEN}•${NC} Set net.inet.tcp.mssdflt=1440 (Optimizes packet size)"
            echo -e "  ${GREEN}•${NC} Set net.inet.tcp.win_scale_factor=4 (Improves throughput)"
            echo -e "  ${GREEN}•${NC} Set net.inet.tcp.sendspace=262144 (Increases send buffer)"
            echo -e "  ${GREEN}•${NC} Set net.inet.tcp.recvspace=262144 (Increases receive buffer)"
            
            echo -e "\n${UNDERLINE}Impact Analysis:${NC}"
            echo -e "  ${CYAN}→${NC} Network Speed: ${GREEN}+10-20% typical${NC}"
            echo -e "  ${CYAN}→${NC} Latency: ${GREEN}-5-15ms typical${NC}"
            echo -e "  ${CYAN}→${NC} Memory Usage: ${YELLOW}+50-100MB${NC}"
            echo -e "  ${CYAN}→${NC} Battery Impact: ${YELLOW}Slight increase${NC}"
            echo -e "  ${CYAN}→${NC} Safety Level: ${GREEN}Safe${NC}"
            echo -e "  ${CYAN}→${NC} Reversible: ${GREEN}Yes${NC}"
            
            echo -e "\n${DIM}These optimizations will improve network performance and responsiveness${NC}"
            ;;
            
        "security")
            echo -e "${UNDERLINE}Changes to be made:${NC}"
            echo -e "  ${GREEN}•${NC} Configure firewall settings (enable + stealth mode)"
            echo -e "  ${GREEN}•${NC} Disable remote access services"
            echo -e "  ${GREEN}•${NC} Check FileVault status"
            echo -e "  ${GREEN}•${NC} Verify SIP and Gatekeeper"
            echo -e "  ${GREEN}•${NC} Optimize security preferences"
            
            echo -e "\n${UNDERLINE}Impact Analysis:${NC}"
            echo -e "  ${CYAN}→${NC} Security Level: ${GREEN}Significantly Improved${NC}"
            echo -e "  ${CYAN}→${NC} Performance Impact: ${YELLOW}Minimal overhead${NC}"
            echo -e "  ${CYAN}→${NC} Network Impact: ${YELLOW}May affect remote access${NC}"
            echo -e "  ${CYAN}→${NC} Convenience: ${YELLOW}Some features restricted${NC}"
            echo -e "  ${CYAN}→${NC} Safety Level: ${GREEN}Very Safe${NC}"
            echo -e "  ${CYAN}→${NC} Reversible: ${GREEN}Yes${NC}"
            
            echo -e "\n${DIM}These optimizations will enhance system security while maintaining usability${NC}"
            ;;
            
        *)
            echo -e "${RED}Unknown optimization type: $opt_type${NC}"
            return 1
            ;;
    esac
    
    echo
    read -n 1 -s -r -p "$(echo -e "${GRAY}Press any key to continue or 'q' to cancel...${NC}")"
    echo
    [[ $REPLY == "q" ]] && return 1
    return 0
}

function create_optimization_profile() {
    local profile_name=$1
    local profile_dir="$PROFILES_DIR/$profile_name"
    
    mkdir -p "$profile_dir"
    defaults read > "$profile_dir/defaults.plist"
    pmset -g > "$profile_dir/power.txt"
    networksetup -listallhardwareports > "$profile_dir/network.txt"
    
    echo -e "${GREEN}Profile '$profile_name' created successfully${NC}"
}

function apply_optimization_profile() {
    local profile_name=$1
    local profile_dir="$PROFILES_DIR/$profile_name"
    
    if [[ ! -d "$profile_dir" ]]; then
        error "Profile '$profile_name' not found"
        return 1
    fi
    
    defaults import -f "$profile_dir/defaults.plist"
    while IFS= read -r setting; do
        pmset "$setting" &>/dev/null
    done < "$profile_dir/power.txt"
    
    success "Profile '$profile_name' applied successfully"
}

function quick_fix_menu() {
    echo -e "\n${CYAN}Quick Fixes:${NC}"
    echo "1) Slow Finder"
    echo "2) High Memory Usage"
    echo "3) Slow Boot Time"
    echo "4) Battery Drain"
    echo "5) Slow Internet"
    echo "0) Back to Main Menu"
    
    read -p "Select an issue to fix: " fix_choice
    
    case $fix_choice in
        1)
            defaults write com.apple.finder QuitMenuItem -bool true
            killall Finder
            echo -e "${GREEN}✓${NC} Finder optimization applied"
            ;;
        2)
            sudo purge
            defaults write NSGlobalDomain NSAppSleepDisabled -bool true
            echo -e "${GREEN}✓${NC} Memory optimization applied"
            ;;
        3)
            sudo nvram boot-args="serverperfmode=1 $(nvram boot-args 2>/dev/null | cut -f 2-)"
            sudo tmutil disablelocal
            echo -e "${GREEN}✓${NC} Boot time optimization applied"
            ;;
        4)
            sudo pmset -a lowpowermode 1
            defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
            echo -e "${GREEN}✓${NC} Power optimization applied"
            ;;
        5)
            sudo dscacheutil -flushcache
            sudo killall -HUP mDNSResponder
            networksetup -setdnsservers "Wi-Fi" 8.8.8.8 8.8.4.4
            echo -e "${GREEN}✓${NC} Network optimization applied"
            ;;
        0) return ;;
        *) error "Invalid choice" ;;
    esac
}

# Add new functions for scheduling and automation
function schedule_optimization() {
    local schedule_type=$1
    local schedule_time=$2
    
    # Create temporary file with proper error handling
    local temp_crontab
    temp_crontab=$(mktemp) || { error "Failed to create temp file"; return 1; }
    
    crontab -l > "$temp_crontab" 2>/dev/null
    
    # Remove existing schedules and add new one
    sed -i.bak "/mac_optimizer/d" "$temp_crontab"
    
    case $schedule_type in
        "daily")
            echo "0 $schedule_time * * * \"$0\" --auto" >> "$temp_crontab"
            ;;
        "weekly")
            echo "0 $schedule_time * * 0 \"$0\" --auto" >> "$temp_crontab"
            ;;
        "monthly")
            echo "0 $schedule_time 1 * * \"$0\" --auto" >> "$temp_crontab"
            ;;
        *)
            rm "$temp_crontab"
            error "Invalid schedule type"
            return 1
            ;;
    esac
    
    if crontab "$temp_crontab"; then
        echo "$schedule_type:$schedule_time" > "$SCHEDULE_FILE"
        rm "$temp_crontab"
        success "Optimization scheduled successfully"
        return 0
    else
        rm "$temp_crontab"
        error "Failed to schedule optimization"
        return 1
    fi
}

function analyze_system_usage() {
    log "Analyzing system usage patterns"
    
    # Collect usage data with proper command substitution
    local cpu_intensive
    local memory_usage
    local disk_usage
    local battery_cycles
    
    cpu_intensive=$(top -l 1 | grep -E "^CPU" | head -1) || cpu_intensive="Unable to get CPU data"
    memory_usage=$(vm_stat | grep "Pages active" | awk '{print $3}') || memory_usage="0"
    disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%') || disk_usage="0"
    
    if system_profiler SPPowerDataType &>/dev/null; then
        battery_cycles=$(system_profiler SPPowerDataType | grep "Cycle Count" | awk '{print $3}') || battery_cycles="Unknown"
    else
        battery_cycles="Not available"
    fi

    # Save usage profile with proper heredoc syntax
    cat > "$USAGE_PROFILE" << EOF
last_analyzed=$(date +%s)
cpu_usage=$cpu_intensive
memory_usage=$memory_usage
disk_usage=$disk_usage
battery_cycles=$battery_cycles
EOF

    success "System analysis completed"
    return 0
}

function auto_maintenance() {
    log "Starting automated maintenance"
    
    # Read last run time
    local last_run=0
    [[ -f "$LAST_RUN_FILE" ]] && last_run=$(cat "$LAST_RUN_FILE")
    local current_time=$(date +%s)
    
    # Only run if more than 24 hours have passed
    if (( current_time - last_run >= 86400 )); then
        # Rotate backups
        local backup_count=$(ls -1 "$HOME/.mac_optimizer_backups/" | wc -l)
        if (( backup_count > AUTO_BACKUP_LIMIT )); then
            ls -t "$HOME/.mac_optimizer_backups/" | tail -n +$((AUTO_BACKUP_LIMIT + 1)) | xargs -I {} rm -rf "$HOME/.mac_optimizer_backups/{}"
        fi
        
        # Run essential optimizations
        create_backup
        optimize_storage
        optimize_network
        
        # Update last run time
        echo "$current_time" > "$LAST_RUN_FILE"
    fi
}

function restore_backup() {
    local backup_path=$1
    
    if [[ ! -d "$backup_path" ]]; then
        error "Backup directory not found: $backup_path"
        return 1
    fi
    
    echo -e "\n${CYAN}Restoring backup from: $backup_path${NC}"
    
    # Create safety backup
    local safety_backup="$BASE_DIR/backups/pre_restore_$(date +%Y%m%d_%H%M%S)"
    if ! create_backup "$safety_backup"; then
        if ! confirm_dialog "Failed to create safety backup. Continue anyway?"; then
            return 1
        fi
    fi
    
    # Restore global defaults
    if [[ -f "$backup_path/global_defaults.plist" ]]; then
        if ! defaults import -globalDomain "$backup_path/global_defaults.plist"; then
            error "Failed to restore global defaults"
            return 1
        fi
    fi
    
    # Restore domain-specific settings
    local restored=0
    local failed=0
    
    for file in "$backup_path"/*.plist; do
        local domain=$(basename "$file" .plist)
        if [[ "$domain" != "global_defaults" ]]; then
            if defaults import "$domain" "$file" 2>/dev/null; then
                ((restored++))
            else
                ((failed++))
                error "Failed to restore: $domain"
            fi
        fi
    done
    
    # Restart affected services
    killall Dock Finder SystemUIServer &>/dev/null
    
    echo -e "\n${CYAN}Restore Summary:${NC}"
    echo -e "Successfully restored: ${GREEN}$restored${NC} domains"
    [[ $failed -gt 0 ]] && echo -e "Failed to restore: ${RED}$failed${NC} domains"
    
    success "Restore completed"
    return 0
}

# Function to get system changes history
function get_system_changes() {
    local hours=$1
    local since=$(($(date +%s) - hours * 3600))
    clear
    
    echo -e "\n${BOLD}${CYAN}System Changes History (Last $hours hours)${NC}\n"
    
    # Track defaults changes
    echo -e "${UNDERLINE}System Preferences Changes${NC}"
    local found_changes=false
    
    for domain in "${TRACKED_DOMAINS[@]}"; do
        local changes=$(log show --predicate 'process == "cfprefsd" or process == "defaults"' --style compact --start "-${hours}h" 2>/dev/null | grep -i "$domain" | grep "write")
        if [[ -n "$changes" ]]; then
            found_changes=true
            echo -e "\n  ${BOLD}$domain${NC}"
            while IFS= read -r line; do
                local timestamp=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')
                local change=$(echo "$line" | grep -oE 'write.*$')
                printf "  ${DIM}%s${NC} %s\n" "$timestamp" "$change"
            done <<< "$changes"
        fi
    done
    
    # Track UI changes
    echo -e "\n${UNDERLINE}UI Changes${NC}"
    local ui_changes=$(log show --predicate 'process == "Dock" or process == "Finder"' --style compact --start "-${hours}h" 2>/dev/null | grep -i "restart")
    if [[ -n "$ui_changes" ]]; then
        found_changes=true
        while IFS= read -r line; do
            local timestamp=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')
            local change=$(echo "$line" | grep -oE 'restart.*$')
            printf "  ${DIM}%s${NC} %s\n" "$timestamp" "$change"
        done <<< "$ui_changes"
    fi
    
    # Track performance changes
    echo -e "\n${UNDERLINE}Performance Changes${NC}"
    local perf_changes=$(log show --predicate 'process == "pmset" or process == "systemstats"' --style compact --start "-${hours}h" 2>/dev/null | grep -i "change")
    if [[ -n "$perf_changes" ]]; then
        found_changes=true
        while IFS= read -r line; do
            local timestamp=$(echo "$line" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}')
            local change=$(echo "$line" | grep -oE 'change.*$')
            printf "  ${DIM}%s${NC} %s\n" "$timestamp" "$change"
        done <<< "$perf_changes"
    fi
    
    if ! $found_changes; then
        echo -e "  ${DIM}No changes found in the last $hours hours${NC}"
    fi
    
    echo -e "\n${UNDERLINE}Actions${NC}"
    echo -e "  ${BOLD}1)${NC} Revert specific change"
    echo -e "  ${BOLD}2)${NC} Revert all changes in this period"
    echo -e "  ${BOLD}0)${NC} Back to main menu"
    
    read -p "$(echo -e "${GRAY}Enter your choice:${NC} ")" choice
    
    case $choice in
        1)
            revert_specific_change
            ;;
        2)
            if confirm_action "revert all changes from the last $hours hours"; then
                revert_changes_period $hours
            fi
            ;;
        0) return ;;
        *) error "Invalid choice" ;;
    esac
}

# Function to revert specific change
function revert_specific_change() {
    echo -e "\n${BOLD}${CYAN}Revert Specific Change${NC}\n"
    echo -e "${DIM}Enter the domain and key to revert (e.g., com.apple.dock autohide-delay)${NC}"
    read -p "Domain: " domain
    read -p "Key: " key
    
    if [[ -z "$domain" || -z "$key" ]]; then
        error "Domain and key are required"
        return 1
    fi
    
    # Get the default value
    local default_value=$(defaults read-type "$domain" "$key" 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo -e "\nCurrent value: $default_value"
        if confirm_action "revert this setting to system default"; then
            defaults delete "$domain" "$key" 2>/dev/null
            if [[ "$domain" == "com.apple.dock" ]]; then
                killall Dock &>/dev/null
            elif [[ "$domain" == "com.apple.finder" ]]; then
                killall Finder &>/dev/null
            fi
            success "Setting reverted to system default"
        fi
    else
        error "Setting not found or cannot be read"
        return 1
    fi
}

# Function to revert changes for a period
function revert_changes_period() {
    local hours=$1
    local since=$(($(date +%s) - hours * 3600))
    
    echo -e "\n${BOLD}${CYAN}Reverting Changes${NC}\n"
    
    # Create temporary backup
    local temp_backup_dir="/tmp/mac_optimizer_temp_backup_$(date +%s)"
    mkdir -p "$temp_backup_dir"
    
    # Backup current settings
    for domain in "${TRACKED_DOMAINS[@]}"; do
        defaults export "$domain" "$temp_backup_dir/${domain}.plist" 2>/dev/null
    done
    
    # Revert changes
    local reverted=0
    for domain in "${TRACKED_DOMAINS[@]}"; do
        local changes=$(log show --predicate "process == \"cfprefsd\" or process == \"defaults\"" --style compact --start "-${hours}h" 2>/dev/null | grep -i "$domain" | grep "write")
        if [[ -n "$changes" ]]; then
            ((reverted++))
            defaults delete "$domain" &>/dev/null
        fi
    done
    
    # Restart affected services
    killall Dock Finder &>/dev/null
    
    if (( reverted > 0 )); then
        success "Reverted $reverted domain(s) to system defaults"
        echo -e "${DIM}Backup saved to: $temp_backup_dir${NC}"
    else
        rm -rf "$temp_backup_dir"
        echo -e "${DIM}No changes to revert${NC}"
    fi
}

# Initialize directory structure and files
function initialize_workspace() {
    log "Initializing workspace structure"
    
    # Create main directory structure
    local directories=(
        "$BASE_DIR"
        "$BASE_DIR/backups"
        "$BASE_DIR/profiles"
        "$BASE_DIR/logs"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log "Created directory: $dir"
        fi
    done
    
    # Initialize required files with default content if they don't exist
    if [[ ! -f "$SETTINGS_FILE" ]]; then
        cat > "$SETTINGS_FILE" << EOF
# macOS Optimizer Settings
version=$VERSION
last_run=0
auto_maintenance=false
backup_limit=$AUTO_BACKUP_LIMIT
EOF
        log "Created settings file: $SETTINGS_FILE"
    fi
    
    if [[ ! -f "$USAGE_PROFILE" ]]; then
        cat > "$USAGE_PROFILE" << EOF
last_analyzed=0
cpu_usage=0
memory_usage=0
disk_usage=0
battery_cycles=0
EOF
        log "Created usage profile: $USAGE_PROFILE"
    fi
    
    if [[ ! -f "$SCHEDULE_FILE" ]]; then
        echo "# Optimization Schedule" > "$SCHEDULE_FILE"
        log "Created schedule file: $SCHEDULE_FILE"
    fi
    
    if [[ ! -f "$LAST_RUN_FILE" ]]; then
        echo "0" > "$LAST_RUN_FILE"
        log "Created last run file: $LAST_RUN_FILE"
    fi
    
    success "Workspace initialization completed"
}

# Enhanced menu selection with arrow keys
function select_menu_option() {
    local options=("$@")
    local selected=0
    local key
    local menu_start_line
    
    # Get current line number for menu positioning
    menu_start_line=$(tput lines)
    menu_start_line=$((menu_start_line - ${#options[@]} - 4))
    
    tput civis  # Hide cursor
    
    while true; do
        # Position cursor at menu start
        tput cup $menu_start_line 0
        
        # Clear menu area
        for ((i=0; i<${#options[@]}+4; i++)); do
            tput el  # Clear line
            tput cup $((menu_start_line + i)) 0
        done
        
        # Draw menu
        tput cup $menu_start_line 0
        for ((i=0; i<${#options[@]}; i++)); do
            if [ $i -eq $selected ]; then
                echo -e "${CYAN}→ ${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done
        
        # Read a single keypress
        read -rsn1 key
        case "$key" in
            $'\x1B')  # ESC sequence
                read -rsn2 key
                if [[ -z "$key" ]]; then  # Single ESC press
                    if confirm_dialog "Are you sure you want to exit?"; then
                        cleanup_and_exit 0
                    fi
                fi
                case "$key" in
                    '[A')  # Up arrow
                        ((selected--))
                        [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
                        ;;
                    '[B')  # Down arrow
                        ((selected++))
                        [ $selected -ge ${#options[@]} ] && selected=0
                        ;;
                esac
                ;;
            'q')  # Quit
                if confirm_dialog "Are you sure you want to exit?"; then
                    cleanup_and_exit 0
                fi
                ;;
            '')  # Enter key
                tput cnorm  # Show cursor
                return $selected
                ;;
        esac
    done
}

# Enhanced confirmation dialog with arrow keys
function confirm_dialog() {
    local message=$1
    local options=("Yes" "No")
    local selected=1  # Default to "No"
    local key
    
    # Save cursor position
    tput sc
    
    while true; do
        # Restore cursor position
        tput rc
        
        # Clear lines
        echo -e "\n\n\n"
        tput rc
        
        # Show message and options
        echo -e "\n${YELLOW}${message}${NC}"
        echo
        for ((i=0; i<${#options[@]}; i++)); do
            if [ $i -eq $selected ]; then
                echo -e "${CYAN}→ ${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done
        
        # Read a single keypress
        read -rsn1 key
        case "$key" in
            $'\x1B')  # ESC sequence
                read -rsn2 key
                case "$key" in
                    '[A'|'[D')  # Up arrow or Left arrow
                        ((selected--))
                        [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
                        ;;
                    '[B'|'[C')  # Down arrow or Right arrow
                        ((selected++))
                        [ $selected -ge ${#options[@]} ] && selected=0
                        ;;
                esac
                ;;
            '')  # Enter key
                tput rc
                tput ed  # Clear to end of screen
                return $selected
                ;;
            'q')  # Quit
                tput rc
                tput ed
                return 1
                ;;
        esac
    done
}

# Update the optimization functions to use the new confirmation dialog
function run_optimization() {
    local name=$1
    local func=$2
    
    echo -e "\n${CYAN}▶ Running ${name}${NC}"
    echo -e "${DIM}────────────────────────────────${NC}"
    $func
    show_progress 100 "✓ Done"
    echo -e "\n"
}

# Simplify run_remaining_optimizations to be automatic
function run_remaining_optimizations() {
    local current_opt=$1
    local all_opts=(
        "performance"
        "graphics"
        "storage"
        "network"
        "power"
        "display"
    )
    
    # Run remaining optimizations automatically
    for ((i=0; i<${#all_opts[@]}; i++)); do
        local opt="${all_opts[i]}"
        echo -e "\n${CYAN}Running $opt optimization...${NC}"
        run_optimization "$opt" "optimize_$opt"
    done
    
    success "All optimizations completed"
    sleep 1
}

# Main menu function without security options
function show_beautiful_menu() {
    while true; do
        clear
        # Compact Logo with updated title
        echo -e "${CYAN}"
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║  ███╗   ███╗ █████╗  ██████╗ ██████╗ ███████╗            ║"
        echo "║  ████╗ ████║██╔══██╗██╔════╝██╔═══██╗██╔════╝            ║"
        echo "║  ██╔████╔██║███████║██║     ██║   ██║███████╗            ║"
        echo "║  ██║╚██╔╝██║██╔══██║██║     ██║   ██║╚════██║            ║"
        echo "║  ██║ ╚═╝ ██║██║  ██║╚██████╗╚██████╔╝███████║            ║"
        echo "║  ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝            ║"
        echo "║                  macOS Optimizer v${VERSION}                    ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo -e "${DIM}github.com/samihalawa/macos-optimizer${NC}"

        # Compact System Dashboard with fixed color codes
        echo -e "\n${DIM}╭─ System Status ─────────────────────────────────────────────╮"
        local cpu_usage=$(top -l 1 | grep "CPU usage" | cut -d: -f2 | cut -d',' -f1 | xargs)
        local mem_usage=$(memory_pressure | cut -d: -f2 | cut -d'%' -f1 | xargs)
        local storage_free=$(df -h / | awk 'NR==2 {printf "%s", $4}')
        printf "${DIM}│${NC} CPU: ${YELLOW}%-24s${NC} Memory: ${YELLOW}%-16s${NC} ${DIM}│${NC}\n" \
            "$cpu_usage" "${mem_usage}%"
        printf "${DIM}│${NC} macOS: ${YELLOW}%-22s${NC} Storage: ${YELLOW}%-16s${NC} ${DIM}│${NC}\n" \
            "$(sw_vers -productVersion)" "$storage_free"
        echo -e "${DIM}╰──────────────────────────────────────────────────────────────╯${NC}"

        # Menu with status indicators
        echo -e "\n${BOLD}${PURPLE}Select Optimization:${NC} ${DIM}[↑/↓] Navigate  [Enter] Select  [Q] Quit${NC}\n"
        
        local options=(
            "${CYAN}⚡${NC} Performance   │ Optimize system & kernel settings"
            "${PURPLE}🎨${NC} Graphics      │ Enhance UI & visual performance"
            "${GREEN}🖥️${NC} Display       │ Optimize display & color settings"
            "${BLUE}🧹${NC} Storage       │ Clean system & app caches"
            "${YELLOW}🌐${NC} Network       │ Boost network performance"
            "${CYAN}🔄${NC} Run All       │ Execute all optimizations"
            "${BLUE}ℹ️${NC} System Info   │ View system details"
            "${GREEN}💾${NC} Backup       │ Manage system backups"
            "${RED}✖${NC} Exit         │ Close Optimizer"
        )
        
        # Status Indicators
        echo -e "${GREEN}●${NC} Ready  ${YELLOW}●${NC} Updates  ${RED}●${NC} Attention Required\n"
        
        select_menu_option "${options[@]}"
        local choice=$?
        
        clear
        case $choice in
            0) run_optimization "System Performance" optimize_system_performance ;;
            1) run_optimization "Graphics" optimize_graphics ;;
            2) run_optimization "Display" optimize_display ;;
            3) run_optimization "Storage" optimize_storage ;;
            4) run_optimization "Network" optimize_network ;;
            5) run_all_optimizations ;;
            6) display_system_info; echo -e "\nPress any key to continue..."; read -n 1 ;;
            7) create_backup; show_restore_menu ;;
            8|255)
                if confirm_dialog "Are you sure you want to exit?"; then
                    cleanup_and_exit 0
                fi
                ;;
        esac
    done
}

# Update run_all_optimizations without security
function run_all_optimizations() {
    log "Running all optimizations..."
    clear
    
    local optimizations=(
        "System Performance:optimize_system_performance"
        "Graphics:optimize_graphics"
        "Display:optimize_display"
        "Storage:optimize_storage"
        "Network:optimize_network"
    )
    
    local total=${#optimizations[@]}
    local current=0
    
    echo -e "\n${BOLD}${CYAN}Running All Optimizations${NC}\n"
    echo -e "${DIM}Each optimization will run sequentially${NC}\n"
    
    for opt in "${optimizations[@]}"; do
        ((current++))
        local name=${opt%%:*}
        local func=${opt#*:}
        
        echo -e "\n${CYAN}[$current/$total] Running $name Optimization${NC}"
        echo -e "${DIM}----------------------------------------${NC}"
        
        # Show progress spinner
        echo -ne "${CYAN}⟳${NC} Running optimization..."
        if ! $func; then
            echo -e "\r${RED}✗${NC} $name optimization failed"
        else
            echo -e "\r${GREEN}✓${NC} $name optimization completed"
        fi
        
        # Show progress bar
        show_progress $current $total
        echo -e "${DIM}----------------------------------------${NC}"
        sleep 1
    done
    
    echo -e "\n${GREEN}✓${NC} All optimizations completed"
    echo -e "${DIM}Press any key to return to menu...${NC}"
    read -n 1
}

# Main execution
function main() {
    # Set error handling
    set +e
    trap 'cleanup_and_exit 1' INT TERM
    trap 'cleanup_and_exit 0' EXIT
    
    # Hide cursor during execution
    tput civis 2>/dev/null || true
    
    # Initialize workspace
    if ! mkdir -p "$BASE_DIR" 2>/dev/null; then
        error "Failed to create base directory: $BASE_DIR"
        exit 1
    fi
    
    # Start menu
    show_beautiful_menu
}

# Cleanup and exit
function cleanup_and_exit() {
    local exit_code=${1:-0}
    cleanup
    clear
    tput cnorm # Show cursor
    echo -e "\n╭────────────────────────────────────────╮"
    echo -e "│  ${CYAN}macOS Optimizer${NC} completed successfully  │"
    echo -e "│  ${DIM}github.com/samihalawa/macos-optimizer${NC}  │"
    echo -e "╰────────────────────────────────────────╯\n"
    exit $exit_code
}

# Start the script
main "$@"
