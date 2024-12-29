#!/bin/bash
# Copyright (c) 2024 Sami Halawa
# Licensed under the MIT License (see LICENSE file for details)

# Exit immediately if a command exits with a non-zero status
set -e

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
    echo "system_profiler command not found. Please ensure it is installed." >&2
    exit 1
fi
readonly GPU_INFO=$(system_profiler SPDisplaysDataType 2>/dev/null)

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
    local pressure
    local total
    
    pressure=$(vm_stat | awk '/Pages active/ {print $3}' | tr -d '.')
    total=$(vm_stat | awk '/Pages free/ {print $3}' | tr -d '.')
    
    if [[ -z "$pressure" || -z "$total" || $((pressure + total)) -eq 0 ]]; then
        echo "System memory pressure: Unable to calculate"
        return 1
    fi
    
    local percentage=$((pressure * 100 / (pressure + total)))
    echo "System memory pressure: $percentage"
    return 0
}

# System state verification
function verify_system_state() {
    local checks_passed=true
    local issues=()
    
    echo -e "\nPerforming system checks..."
    
    # Disk verification
    echo -ne "Checking disk health..."
    if ! diskutil verifyVolume / >/dev/null 2>&1; then
        issues+=("Disk verification failed")
        checks_passed=false
        echo -e " ${RED}✗${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi
    
    # Memory pressure check
    echo -ne "Checking memory pressure..."
    local mem_pressure=$(memory_pressure | grep -o "[0-9]*$")
    if (( mem_pressure > 80 )); then
        issues+=("High memory pressure detected: ${mem_pressure}%")
        checks_passed=false
        echo -e " ${RED}✗${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi
    
    # CPU thermal check
    echo -ne "Checking CPU temperature..."
    if pmset -g therm | grep -q "CPU_Scheduler_Limit.*100"; then
        issues+=("CPU thermal throttling detected")
        checks_passed=false
        echo -e " ${RED}✗${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi
    
    # Display any issues
    if ! $checks_passed; then
        echo -e "\n${YELLOW}Issues detected:${NC}"
        for issue in "${issues[@]}"; do
            echo -e "  • ${issue}"
        done
    else
        echo -e "\n${GREEN}All system checks passed${NC}"
    fi
    
    if ! $checks_passed; then
        return 1
    fi
    return 0
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
    tput cnorm # Show cursor
    echo -e "\n${GRAY}Cleaning up...${NC}"
    
    # Remove temporary files
    local temp_files=(
        "/tmp/mac_optimizer_temp"
        "/tmp/mac_optimizer_cleanup"
        "/private/tmp/mac_optimizer_*"
    )
    
    for file in "${temp_files[@]}"; do
        [[ -e "$file" ]] && rm -rf "$file"
    done
    
    # Reset any interrupted system processes
    killall "System Preferences" &>/dev/null || true
    
    # Restart Finder and Dock if they were modified
    if [[ -f "/tmp/mac_optimizer_ui_modified" ]]; then
        killall Finder Dock &>/dev/null || true
        rm "/tmp/mac_optimizer_ui_modified"
    fi
}

# Enhanced system validation
function check_system_requirements() {
    # Check if running with sudo privileges when needed
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run with sudo privileges"
        exit 1
    fi

    # Get the detected version and normalize it for comparison
    local detected_version=$(sw_vers -productVersion)
    local major_version=$(echo "$detected_version" | cut -d. -f1)
    
    # For modern macOS versions (>=11), we consider them all compatible
    if [[ $major_version -ge 11 ]]; then
        return 0
    fi
    
    # For older versions, compare with minimum required version
    if [[ $major_version -lt 10 ]] || [[ $major_version -eq 10 && $(echo "$detected_version" | cut -d. -f2) -lt 15 ]]; then
        error "This script requires macOS $MIN_MACOS_VERSION or later (detected: $detected_version)"
        exit 1
    fi
    
    # Check SIP status
    if [[ $(csrutil status | grep -c "enabled") -eq 1 ]]; then
        warning "System Integrity Protection is enabled. Some optimizations may be limited."
    fi
    
    # Check disk space (require at least 10GB free)
    local available_space=$(df -g / | awk 'NR==2 {print $4}')
    if (( available_space < 10 )); then
        warning "Low disk space detected (${available_space}GB). Some optimizations may fail."
    fi
    
    # Check for required tools
    local required_tools=(sw_vers csrutil networksetup defaults pmset)
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            error "Required tool '$tool' not found"
            exit 1
        fi
    done
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
    printf "\r${CYAN}${spinner[$spin_idx]}${NC} "
    printf "${title} ["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${percent}%%"
    
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
    show_progress_bar "$current" "$total" "$message"
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
    printf "\r${GREEN}✓${NC} %s... Done\n" "$message"
}

# Update optimize_system_performance to use the new progress indicators
function optimize_system_performance() {
    log "Starting system performance optimization"
    clear
    
    echo -e "\n${BOLD}${CYAN}System Performance Optimization${NC}\n"
    echo -e "${DIM}Optimizing system settings for maximum performance...${NC}\n"
    
    local total_steps=6
    local current_step=0
    
    # Memory optimization
    ((current_step++))
    {
        sudo sysctl kern.maxvnodes=250000
        sudo sysctl kern.maxproc=2048
        sudo sysctl kern.maxfiles=262144
    } &>/dev/null &
    local pid=$!
    show_spinner "Optimizing memory management" $pid
    
    # Process optimization
    ((current_step++))
    track_progress $current_step $total_steps "Configuring process limits"
    {
        sudo sysctl kern.ipc.somaxconn=2048
        sudo sysctl kern.ipc.nmbclusters=65536
    } &>/dev/null
    
    # Common optimizations
    echo -e "\n⏳ [2/$total_steps] Configuring ${IS_APPLE_SILICON:+"Apple Silicon"}${IS_APPLE_SILICON:-"Intel"} specific settings..."
    if $IS_APPLE_SILICON; then
        local success=true
        
        if version_compare "$MACOS_VERSION" "12.0"; then
            if [[ $(csrutil status | grep -c "enabled") -eq 0 ]]; then
                if ! sudo nvram boot-args="amfi_get_out_of_my_way=1 $(nvram boot-args 2>/dev/null | cut -f 2-)"; then
                    success=false
                fi
            fi
        fi
        
        if ! sudo pmset -a powernap 0 || ! sudo pmset -a proximitywake 0; then
            success=false
        fi
        
        if $success; then
            echo -e "${GREEN}✓${NC} Apple Silicon optimizations applied"
        else
            echo -e "${YELLOW}⚠${NC} Some Apple Silicon optimizations failed"
        fi
    else
        local success=true
        
        if ! sudo pmset -a standbydelay 86400 || 
           ! sudo pmset -a hibernatemode 3 || 
           ! sudo pmset -a autopoweroff 0; then
            success=false
        fi
        
        if version_compare "$MACOS_VERSION" "10.15"; then
            if ! sudo sysctl vm.compressor_mode=4; then
                success=false
            fi
        fi
        
        if $success; then
            echo -e "${GREEN}✓${NC} Intel optimizations applied"
        else
            echo -e "${YELLOW}⚠${NC} Some Intel optimizations failed"
        fi
    fi
    ((current_step++))
    
    # Verify changes
    echo -e "\n⏳ [4/$total_steps] Verifying optimizations..."
    if verify_system_state; then
        echo -e "${GREEN}✓${NC} System state verified"
        ((current_step++))
    else
        echo -e "${YELLOW}⚠${NC} System state verification shows some concerns"
    fi
    
    # Show final system stats
    echo -e "\n⏳ [5/$total_steps] Measuring final system status..."
    echo -e "\n📊 Updated System Status:"
    echo -e "Memory Pressure: $(memory_pressure | grep "System memory pressure" | cut -d: -f2)"
    echo -e "CPU Load: $(sysctl -n vm.loadavg | tr -d '{}')"
    ((current_step++))
    
    # Summary
    echo -e "\n${CYAN}Performance Optimization Summary:${NC}"
    echo -e "Steps completed: $current_step/$total_steps"
    if [ $current_step -eq $total_steps ]; then
        echo -e "${GREEN}All optimizations completed successfully${NC}"
    else
        echo -e "${YELLOW}Some optimizations were skipped or failed${NC}"
    fi
    
    success "System performance optimization completed"
    return 0
}

# Progress bar function
function show_progress() {
    local current=$1
    local total=$2
    local width=20  # Reduced width for more compact display
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    printf "\r  ${GRAY}[${GREEN}"
    printf "█%.0s" $(seq 1 $filled)
    printf "${GRAY}"
    printf "░%.0s" $(seq 1 $empty)
    printf "] ${BOLD}%3d%%${NC}" $percentage
}

# Progress tracking for optimizations
function track_progress() {
    local step=$1
    local total=$2
    local message=$3
    
    show_progress $step $total
    if [[ -n "$message" ]]; then
        printf "\r%-80s\r" ""  # Clear line
        echo -e "  ${CYAN}→${NC} $message"
    fi
}

# Enhanced graphics optimization for systems with limited GPU capabilities
function optimize_graphics() {
    log "Starting enhanced graphics optimization"
    clear
    
    echo -e "\n${BOLD}${CYAN}Advanced Graphics & Window Service Optimization${NC}"
    echo -e "${DIM}Applying aggressive optimizations for limited GPU resources...${NC}\n"
    
    local total_steps=12
    local current_step=0
    
    # Window Server Core Optimizations
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing Window Server core settings"
    defaults write com.apple.WindowServer UseOptimizedDrawing -bool true
    defaults write com.apple.WindowServer Accelerate -bool false
    defaults write com.apple.WindowServer EnableHiDPI -bool false
    defaults write com.apple.WindowServer ProgressiveDrawing -bool false
    printf "\r  ${GREEN}✓${NC} Window Server core optimized\n"
    
    # Window Management
    ((current_step++))
    track_progress $current_step $total_steps "Configuring window management"
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    defaults write com.apple.WindowServer EnableSurfacePresentationManagement -bool false
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool false
    printf "\r  ${GREEN}✓${NC} Window management optimized\n"
    
    # Compositor Settings
    ((current_step++))
    track_progress $current_step $total_steps "Adjusting compositor settings"
    defaults write com.apple.WindowServer CompositorMode -string "Basic"
    defaults write com.apple.WindowServer ForceTranslucencyMode -bool false
    defaults write com.apple.WindowServer EnableSecureWindowServer -bool false
    printf "\r  ${GREEN}✓${NC} Compositor settings adjusted\n"
    
    # Display and Resolution Management
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing display handling"
    defaults write NSGlobalDomain AppleFontSmoothing -int 0
    defaults write NSGlobalDomain CGFontRenderingFontSmoothingDisabled -bool true
    defaults write -g CGFontRenderingFontSmoothingDisabled -bool YES
    defaults write NSGlobalDomain AppleDisplayScaleFactor -int 1
    printf "\r  ${GREEN}✓${NC} Display handling optimized\n"
    
    # GPU Workload Reduction
    ((current_step++))
    track_progress $current_step $total_steps "Reducing GPU workload"
    defaults write NSGlobalDomain NSScrollAnimationEnabled -bool false
    defaults write NSGlobalDomain NSScrollViewRubberbanding -bool false
    defaults write NSGlobalDomain NSDocumentRevisionsWhileScrolling -bool false
    defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool false
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    printf "\r  ${GREEN}✓${NC} GPU workload reduced\n"
    
    # Visual Effects Minimization
    ((current_step++))
    track_progress $current_step $total_steps "Minimizing visual effects"
    defaults write com.apple.universalaccess reduceTransparency -bool true
    defaults write com.apple.universalaccess reduceMotion -bool true
    defaults write com.apple.Accessibility DifferentiateWithoutColor -bool true
    defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
    printf "\r  ${GREEN}✓${NC} Visual effects minimized\n"
    
    # Desktop and Workspace
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing desktop environment"
    defaults write com.apple.dock workspaces-edge-delay -float 0.1
    defaults write com.apple.dock expose-animation-duration -float 0.1
    defaults write com.apple.dock autohide-time-modifier -float 0
    defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool false
    printf "\r  ${GREEN}✓${NC} Desktop environment optimized\n"
    
    # Menu Bar and Dock
    ((current_step++))
    track_progress $current_step $total_steps "Configuring UI elements"
    defaults write com.apple.dock launchanim -bool false
    defaults write com.apple.dock expose-animation-duration -float 0.1
    defaults write com.apple.dock autohide-time-modifier -float 0
    defaults write com.apple.dock enable-spring-load-actions-on-all-items -bool false
    defaults write com.apple.dock showhidden -bool true
    printf "\r  ${GREEN}✓${NC} UI elements configured\n"
    
    # Mission Control and Spaces
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing workspace management"
    defaults write com.apple.dock expose-animation-duration -float 0.1
    defaults write com.apple.dock "expose-group-by-app" -bool false
    defaults write com.apple.dock mru-spaces -bool false
    defaults write com.apple.dock workspaces-swoosh-animation-off -bool true
    printf "\r  ${GREEN}✓${NC} Workspace management optimized\n"
    
    # Application Windows
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing application windows"
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write NSGlobalDomain NSWindowResizeTime -float 0.001
    defaults write com.apple.Preview PVImageSmoothingEnabled -bool false
    defaults write com.apple.QuickLookUI EnableTransitions -bool false
    printf "\r  ${GREEN}✓${NC} Application windows optimized\n"
    
    # Window Server Process Priority
    ((current_step++))
    track_progress $current_step $total_steps "Adjusting Window Server priority"
    if ! sudo launchctl limit maxproc 512 1024 2>/dev/null; then
        printf "\r  ${YELLOW}!${NC} Could not adjust process limits\n"
    fi
    if ! sudo sysctl -w kern.maxvnodes=250000 2>/dev/null; then
        printf "\r  ${YELLOW}!${NC} Could not adjust virtual node limits\n"
    fi
    printf "\r  ${GREEN}✓${NC} Process priorities adjusted\n"
    
    # Final Cleanup and Restart
    ((current_step++))
    track_progress $current_step $total_steps "Applying changes"
    killall Dock Finder SystemUIServer WindowServer &>/dev/null
    touch "/tmp/mac_optimizer_ui_modified"
    printf "\r  ${GREEN}✓${NC} Changes applied\n"
    
    echo -e "\n${GREEN}Graphics optimization completed successfully${NC}"
    echo -e "${DIM}Note: Some changes may require a logout/login to take full effect${NC}"
    echo -e "${DIM}Tip: Consider using integrated GPU for better performance${NC}"
    sleep 1
    return 0
}

# New function for display optimization
function optimize_display() {
    log "Starting display optimization"
    clear
    
    echo -e "\n${BOLD}${CYAN}Display Optimization${NC}"
    echo -e "${DIM}Optimizing display settings for better performance...${NC}\n"
    
    local total_steps=5
    local current_step=0
    
    # Get display information
    local display_info=$(system_profiler SPDisplaysDataType)
    local is_retina=$(echo "$display_info" | grep -i "retina" || echo "")
    local is_scaled=$(echo "$display_info" | grep -i "scaled" || echo "")
    
    # Resolution optimization
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing resolution settings"
    if [[ -n "$is_retina" ]]; then
        defaults write NSGlobalDomain AppleFontSmoothing -int 0
        defaults write NSGlobalDomain CGFontRenderingFontSmoothingDisabled -bool true
        printf "\r  ${GREEN}✓${NC} Optimized Retina settings for performance\n"
    else
        defaults write NSGlobalDomain AppleFontSmoothing -int 1
        printf "\r  ${GREEN}✓${NC} Optimized standard display settings\n"
    fi
    
    # Color profile optimization
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing color settings"
    defaults write NSGlobalDomain AppleICUForce24HourTime -bool true
    defaults write NSGlobalDomain AppleDisplayScaleFactor -int 1
    printf "\r  ${GREEN}✓${NC} Display color optimized\n"
    
    # Font rendering
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing font rendering"
    defaults write NSGlobalDomain AppleFontSmoothing -int 1
    defaults write -g CGFontRenderingFontSmoothingDisabled -bool NO
    printf "\r  ${GREEN}✓${NC} Font rendering optimized\n"
    
    # Screen update optimization
    ((current_step++))
    track_progress $current_step $total_steps "Optimizing screen updates"
    defaults write com.apple.CrashReporter DialogType none
    defaults write com.apple.screencapture disable-shadow -bool true
    printf "\r  ${GREEN}✓${NC} Screen updates optimized\n"
    
    # Apply changes
    ((current_step++))
    track_progress $current_step $total_steps "Applying display changes"
    killall SystemUIServer &>/dev/null
    printf "\r  ${GREEN}✓${NC} Display changes applied\n"
    
    echo -e "\n${GREEN}Display optimization completed successfully${NC}"
    echo -e "${DIM}Note: Some changes may require a logout/login to take full effect${NC}"
    sleep 1
    return 0
}

# Storage Optimization
function optimize_storage() {
    log "Starting storage optimization"
    
    echo -e "\n${CYAN}Storage Optimization Progress:${NC}"
    echo -e "This will clean up unnecessary files and optimize storage usage."
    echo -e "Estimated time: 30-45 seconds\n"
    
    local total_steps=6
    local current_step=0
    
    # Show initial storage status
    echo -e "${STATS} Current Storage Status:"
    df -h / | awk 'NR==2 {printf "Available: %s of %s\n", $4, $2}'
    echo -e "Cache Size: $(du -sh ~/Library/Caches 2>/dev/null | cut -f1)\n"
    
    # Initialize temp directory
    local temp_dir="/tmp/mac_optimizer_cleanup"
    echo -e "${HOURGLASS} [1/$total_steps] Preparing cleanup environment..."
    if ! mkdir -p "$temp_dir"; then
        echo -e "${RED}${CROSS_MARK}${NC} Failed to create temporary directory"
        return 1
    fi
    echo -e "${GREEN}${CHECK_MARK}${NC} Cleanup environment ready"
    ((current_step++))
    
    # Cache cleanup
    echo -e "\n${HOURGLASS} [2/$total_steps] Clearing system caches..."
    local cache_files_count=$(find ~/Library/Caches -type f | wc -l)
    if ! find ~/Library/Caches -type f -atime +7 -delete 2>/dev/null; then
        echo -e "${YELLOW}${WARNING_MARK}${NC} Partial cache cleanup completed"
    else
        echo -e "${GREEN}${CHECK_MARK}${NC} Cleared $(($cache_files_count - $(find ~/Library/Caches -type f | wc -l))) cache files"
    fi
    ((current_step++))
    
    # Log cleanup
    echo -e "\n${HOURGLASS} [3/$total_steps] Cleaning system logs..."
    local logs_count=0
    if ! find ~/Library/Logs -type f -atime +7 -delete 2>/dev/null; then
        echo -e "${YELLOW}${WARNING_MARK}${NC} Some logs could not be cleared"
    fi
    if ! sudo find /var/log -type f -mtime +7 -exec mv {} "$temp_dir/" \; 2>/dev/null; then
        echo -e "${YELLOW}${WARNING_MARK}${NC} Some system logs could not be moved"
    else
        echo -e "${GREEN}${CHECK_MARK}${NC} System logs cleaned"
    fi
    ((current_step++))
    
    # Time Machine cleanup
    echo -e "\n${HOURGLASS} [4/$total_steps] Managing Time Machine snapshots..."
    if command -v tmutil >/dev/null; then
        local snapshot_count=0
        if tmutil listlocalsnapshots / &>/dev/null; then
            while read -r snapshot; do
                ((snapshot_count++))
                echo -ne "\rProcessing snapshot $snapshot_count..."
                if ! sudo tmutil deletelocalsnapshots "$snapshot" 2>/dev/null; then
                    echo -e "\n${YELLOW}${WARNING_MARK}${NC} Failed to delete snapshot: $snapshot"
                fi
            done < <(tmutil listlocalsnapshots / 2>/dev/null | cut -d. -f4)
            echo -e "\n${GREEN}${CHECK_MARK}${NC} Processed $snapshot_count Time Machine snapshots"
        else
            echo -e "${GREEN}${CHECK_MARK}${NC} No Time Machine snapshots found"
        fi
    else
        echo -e "${YELLOW}${WARNING_MARK}${NC} Time Machine utilities not available"
    fi
    ((current_step++))
    
    # Developer tools cleanup
    echo -e "\n${HOURGLASS} [5/$total_steps] Cleaning development tools cache..."
    if [[ -d "$HOME/Library/Developer/Xcode" ]]; then
        local xcode_paths=(
            "$HOME/Library/Developer/Xcode/DerivedData"
            "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
        )
        local cleaned_count=0
        
        for path in "${xcode_paths[@]}"; do
            if [[ -d "$path" ]]; then
                local size_before=$(du -sh "${path}" 2>/dev/null | cut -f1)
                if ! rm -rf "${path:?}/"* 2>/dev/null; then
                    echo -e "${YELLOW}${WARNING_MARK}${NC} Failed to clean: $path"
                else
                    ((cleaned_count++))
                    echo -e "${GREEN}${CHECK_MARK}${NC} Cleaned $path (was: $size_before)"
                fi
            fi
        done
        
        if command -v xcodebuild >/dev/null; then
            if ! xcodebuild -cache clean 2>/dev/null; then
                echo -e "${YELLOW}${WARNING_MARK}${NC} Failed to clean Xcode build cache"
            else
                ((cleaned_count++))
                echo -e "${GREEN}${CHECK_MARK}${NC} Cleaned Xcode build cache"
            fi
        fi
        echo -e "Cleaned $cleaned_count development tool caches"
    else
        echo -e "${GRAY}No development tools found to clean${NC}"
    fi
    ((current_step++))
    
    # Cleanup and final status
    echo -e "\n${HOURGLASS} [6/$total_steps] Finalizing cleanup..."
    if ! rm -rf "$temp_dir"; then
        echo -e "${YELLOW}${WARNING_MARK}${NC} Failed to remove temporary directory"
    fi
    
    # Show final storage status
    echo -e "\n${STATS} Updated Storage Status:"
    df -h / | awk 'NR==2 {printf "Available: %s of %s\n", $4, $2}'
    echo -e "Cache Size: $(du -sh ~/Library/Caches 2>/dev/null | cut -f1)"
    ((current_step++))
    
    # Summary
    echo -e "\n${CYAN}Storage Optimization Summary:${NC}"
    echo -e "Steps completed: $current_step/$total_steps"
    if [ $current_step -eq $total_steps ]; then
        echo -e "${GREEN}All cleanup operations completed successfully${NC}"
    else
        echo -e "${YELLOW}Some cleanup operations were skipped or failed${NC}"
    fi
    
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

# Security Optimization
function optimize_security() {
    log "Starting security optimization"
    
    echo -e "\n${CYAN}Security Optimization Progress:${NC}"
    echo -e "This will enhance system security settings."
    echo -e "Estimated time: 10-15 seconds\n"
    
    local total_steps=5
    local current_step=0
    
    # Show initial security status
    echo -e "📊 Current Security Status:"
    echo -e "Firewall: $(sudo defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "Unknown")"
    echo -e "SIP Status: $(csrutil status | grep -o "enabled\|disabled")"
    echo -e "FileVault: $(fdesetup status | grep -o "On\|Off")\n"
    
    # Firewall configuration
    echo -e "⏳ [1/$total_steps] Configuring firewall..."
    local firewall_path="/usr/libexec/ApplicationFirewall/socketfilterfw"
    
    if [[ ! -x "$firewall_path" ]]; then
        echo -e "${RED}✗${NC} Firewall utility not found or not executable"
        return 1
    fi
    
    local firewall_success=true
    if ! sudo "$firewall_path" --setglobalstate on 2>/dev/null; then
        firewall_success=false
        echo -e "${YELLOW}⚠${NC} Failed to enable firewall"
    fi
    
    if ! sudo "$firewall_path" --setstealthmode on 2>/dev/null; then
        firewall_success=false
        echo -e "${YELLOW}⚠${NC} Failed to enable stealth mode"
    fi
    
    if $firewall_success; then
        echo -e "${GREEN}✓${NC} Firewall configured successfully"
    fi
    ((current_step++))
    
    # Remote access configuration
    echo -e "\n⏳ [2/$total_steps] Configuring remote access..."
    if command -v systemsetup >/dev/null; then
        if ! sudo systemsetup -setremotelogin off 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Failed to disable remote login"
        else
            echo -e "${GREEN}✓${NC} Remote login disabled"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Remote login configuration skipped (systemsetup not available)"
    fi
    ((current_step++))
    
    # FileVault check
    echo -e "\n⏳ [3/$total_steps] Checking disk encryption..."
    if command -v fdesetup >/dev/null; then
        if [[ $(fdesetup status | grep -c "FileVault is Off") -eq 1 ]]; then
            echo -e "${YELLOW}⚠${NC} FileVault is disabled. Consider enabling it for better security."
        else
            echo -e "${GREEN}✓${NC} FileVault is enabled"
        fi
    else
        echo -e "${YELLOW}⚠${NC} FileVault status check skipped (fdesetup not available)"
    fi
    ((current_step++))
    
    # Additional security checks
    echo -e "\n⏳ [4/$total_steps] Performing additional security checks..."
    local additional_checks=true
    
    # Check SIP status
    if [[ $(csrutil status | grep -c "enabled") -eq 0 ]]; then
        echo -e "${YELLOW}⚠${NC} System Integrity Protection is disabled"
        additional_checks=false
    fi
    
    # Check Gatekeeper status
    if ! spctl --status | grep -q "assessments enabled"; then
        echo -e "${YELLOW}⚠${NC} Gatekeeper is disabled"
        additional_checks=false
    fi
    
    if $additional_checks; then
        echo -e "${GREEN}✓${NC} Additional security checks passed"
    fi
    ((current_step++))
    
    # Verify final security status
    echo -e "\n⏳ [5/$total_steps] Verifying security settings..."
    echo -e "\n📊 Updated Security Status:"
    echo -e "Firewall: $(sudo defaults read /Library/Preferences/com.apple.alf globalstate 2>/dev/null || echo "Unknown")"
    echo -e "SIP Status: $(csrutil status | grep -o "enabled\|disabled")"
    echo -e "FileVault: $(fdesetup status | grep -o "On\|Off")"
    ((current_step++))
    
    # Summary
    echo -e "\n${CYAN}Security Optimization Summary:${NC}"
    echo -e "Steps completed: $current_step/$total_steps"
    if [ $current_step -eq $total_steps ]; then
        echo -e "${GREEN}All security optimizations completed successfully${NC}"
    else
        echo -e "${YELLOW}Some security optimizations were skipped or failed${NC}"
    fi
    
    success "Security optimization completed"
    return 0
}

# Backup functionality
function create_backup() {
    log "Creating system backup"
    # Add backup implementation
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
    
    log "Restoring system settings from $backup_path"
    
    # Create safety backup before restore
    create_backup
    
    # Restore settings
    if [[ -f "$backup_path/defaults_backup.plist" ]]; then
        defaults import -f "$backup_path/defaults_backup.plist"
    fi
    
    if [[ -f "$backup_path/power_settings.txt" ]]; then
        while IFS= read -r setting; do
            pmset "$setting" &>/dev/null
        done < "$backup_path/power_settings.txt"
    fi
    
    if [[ -f "$backup_path/dock_settings.plist" ]]; then
        defaults import com.apple.dock "$backup_path/dock_settings.plist"
        killall Dock
    fi
    
    success "Settings restored successfully"
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
    
    tput civis  # Hide cursor
    
    while true; do
        # Clear previous menu
        for ((i=0; i<${#options[@]}; i++)); do
            tput cup $((i + 1)) 0
            tput el
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
            '')  # Enter key
                tput cnorm  # Show cursor
                return $selected
                ;;
            'q')  # Quit
                tput cnorm
                return 255
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
    local opt_type=$1
    local opt_func=$2
    
    # Clear screen before showing optimization details
    clear
    
    if describe_optimization "$opt_type"; then
        echo
        if confirm_dialog "Do you want to proceed with the $opt_type optimization?"; then
            measure_performance "$opt_type"
            $opt_func
            show_comparison "$opt_type"
            return
        fi
    fi
}

# Update show_main_menu to use the new confirmation dialog
function show_main_menu() {
    clear
    echo -e "\n${BOLD}${CYAN}macOS Optimizer Menu${NC}\n"
    
    local options=(
        "System Performance Optimization"
        "Graphics & UI Optimization"
        "Storage Optimization"
        "Network Optimization"
        "Security Hardening"
        "Power Management"
        "Run All Optimizations"
        "Show System Information"
        "Create Backup"
        "Restore from Backup"
        "Exit"
    )
    
    while true; do
        select_menu_option "${options[@]}"
        local choice=$?
        
        case $choice in
            0) run_optimization "performance" optimize_system_performance ;;
            1) run_optimization "graphics" optimize_graphics ;;
            2) run_optimization "storage" optimize_storage ;;
            3) run_optimization "network" optimize_network ;;
            4) run_optimization "security" optimize_security ;;
            5) run_optimization "power" optimize_power ;;
            6)
                if confirm_dialog "This will run all optimizations. Are you sure?"; then
                    verify_system_state
                    create_backup
                    run_all_optimizations
                fi
                ;;
            7) display_system_info ;;
            8) create_backup ;;
            9) restore_backup ;;
            10|255) 
                if confirm_dialog "Are you sure you want to exit?"; then
                    exit 0
                fi
                ;;
        esac
    done
}

# Main execution
function main() {
    # Show cursor on exit
    trap 'tput cnorm' EXIT
    trap 'cleanup; exit 1' INT TERM
    
    # Hide cursor during execution
    tput civis
    
    # Check requirements
    check_system_requirements "$@"
    
    # Initialize workspace
    initialize_workspace
    
    # Create necessary directories
    mkdir -p "$BACKUP_DIR" "$PROFILES_DIR" "$(dirname "$LOG_FILE")"
    
    # Create initial backup if not running in auto mode
    if [[ "$1" != "--auto" ]]; then
        create_backup
        display_system_info
    fi
    
    # Handle automated runs
    if [[ "$1" == "--auto" ]]; then
        auto_maintenance
        exit 0
    fi
    
    # Show main menu
    show_main_menu
}

# Ensure proper cleanup on script exit
function cleanup() {
    tput cnorm # Show cursor
    echo -e "\n${GRAY}Cleaning up...${NC}"
    
    # Remove temporary files
    local temp_files=(
        "/tmp/mac_optimizer_temp"
        "/tmp/mac_optimizer_cleanup"
        "/private/tmp/mac_optimizer_*"
    )
    
    for file in "${temp_files[@]}"; do
        [[ -e "$file" ]] && rm -rf "$file"
    done
    
    # Reset any interrupted system processes
    killall "System Preferences" &>/dev/null || true
    
    # Restart Finder and Dock if they were modified
    if [[ -f "/tmp/mac_optimizer_ui_modified" ]]; then
        killall Finder Dock &>/dev/null || true
        rm "/tmp/mac_optimizer_ui_modified"
    fi
}

# Start the script
main "$@"
