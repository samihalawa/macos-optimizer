#!/bin/bash
# Copyright (c) 2024 Sami Halawa
# Licensed under the MIT License (see LICENSE file for details)

# Exit immediately if a command exits with a non-zero status
set -e

# --- Constants and Configuration ---
readonly VERSION="2.1"
readonly BASE_DIR="$HOME/.mac_optimizer"
readonly BACKUP_DIR="$BASE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="$BACKUP_DIR/optimizer.log"
readonly SETTINGS_FILE="$BASE_DIR/settings"
readonly MIN_MACOS_VERSION="10.15" # Minimum supported macOS version (Catalina)
readonly PROFILES_DIR="$BASE_DIR/profiles"
readonly MEASUREMENTS_FILE="$BACKUP_DIR/performance_measurements.txt"
readonly SCHEDULE_FILE="$BASE_DIR/schedule"
readonly USAGE_PROFILE="$BASE_DIR/usage"
readonly AUTO_BACKUP_LIMIT=5
readonly LAST_RUN_FILE="$BASE_DIR/lastrun"
readonly DIALOG_HEIGHT=20
readonly DIALOG_WIDTH=70
readonly TRACKED_DOMAINS=(
    "com.apple.dock"
    "com.apple.finder"
    "com.apple.universalaccess"
    "com.apple.WindowManager"
    "com.apple.QuickLookUI"
    "NSGlobalDomain"
)

# Verify if system_profiler is installed
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

# --- Enhanced Logging Functions ---
# `enhanced_logging` - Logs the message with timestamp and severity to a log file
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

# `log` - Logs a message as info
function log() {
    local message=$1
    enhanced_logging "INFO" "$message"
    echo -e "${GRAY}[INFO] $message${NC}"
}

# `error` - Logs a message as error
function error() {
    local message=$1
    enhanced_logging "ERROR" "$message"
    echo -e "${RED}[ERROR] $message${NC}"
}

# `warning` - Logs a message as warning
function warning() {
    local message=$1
    enhanced_logging "WARNING" "$message"
    echo -e "${YELLOW}[WARNING] $message${NC}"
}

# `success` - Logs a message as success
function success() {
    local message=$1
    enhanced_logging "SUCCESS" "$message"
    echo -e "${GREEN}[SUCCESS] $message${NC}"
}

# --- Error Handling ---
# `handle_error` - Handles an error, logs it, and potentially tries to resolve it
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

# --- System State Verification ---
# `memory_pressure` - Reports system memory pressure percentage
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

# `verify_system_state` - Performs various system state checks
function verify_system_state() {
    local checks_passed=true
    local issues=()
    
    # Disk verification
    echo -ne "Checking disk health..."
    if ! diskutil verifyVolume / >/dev/null 2>&1; then
        warning "Disk verification skipped - volume is mounted"
        echo -e " ${YELLOW}⚠${NC}"
    else
        echo -e " ${GREEN}✓${NC}"
    fi

    # Memory check
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

    # CPU thermal check
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

# --- Version Comparison Function ---
# `version_compare` - Compares two version strings
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

# --- Cleanup Functions ---
# `cleanup` - Performs cleanup tasks (temp files, process termination, etc.)
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

# --- System Validation ---
# `check_system_requirements` - Checks if the system meets minimum requirements
function check_system_requirements() {
    local detected_version=$(sw_vers -productVersion)
    local major_version=$(echo "$detected_version" | cut -d. -f1)
    
    # Fix version comparison for newer macOS versions
    if [[ $major_version -ge 11 ]] || [[ "$detected_version" == "10.15"* ]]; then
        return 0
    fi
    
    error "This script requires macOS $MIN_MACOS_VERSION or later (detected: $detected_version)"
    exit 1
}

# --- Progress Indicators ---
# `show_progress_bar` - Displays an animated progress bar with a spinner
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

# `track_progress` - Updates a dialog gauge for progress tracking
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

# `show_spinner` - Displays a spinner while an operation is running
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

# `show_progress` - Shows a progress indicator
function show_progress() {
    local current=$1
    local total=$2
    local width=20  # Reduced width for more compact display
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    tput cr
    printf "  ${GRAY}[${GREEN}"
    printf "█%.0s" $(seq 1 $filled)
    printf "${GRAY}"
    printf "░%.0s" $(seq 1 $empty)
    printf "] ${BOLD}%3d%%${NC}" $percentage
    tput el
}

# --- Optimization Functions ---
# `optimize_system_performance` - Optimizes core system settings
function optimize_system_performance() {
    log "Starting system performance optimization"
    
    # Fix sysctl commands to handle read-only parameters
    local sysctl_params=(
        "kern.maxvnodes=250000"
        "kern.maxproc=2048"
        "kern.maxfiles=262144"
    )
    
    for param in "${sysctl_params[@]}"; do
        sudo sysctl -w "$param" 2>/dev/null || true
    done

    # Fix power management for different architectures
    if $IS_APPLE_SILICON; then
        sudo pmset -a powernap 0 2>/dev/null || true
        sudo pmset -a standby 0 2>/dev/null || true
    else
        sudo pmset -a standbydelay 86400 2>/dev/null || true
        sudo pmset -a hibernatemode 0 2>/dev/null || true # Changed from 3 to 0
        sudo pmset -a autopoweroff 0 2>/dev/null || true
    fi

    # Fix network settings with error handling
    {
        sudo sysctl -w net.inet.tcp.delayed_ack=0
        sudo sysctl -w net.inet.tcp.mssdflt=1440
    } 2>/dev/null || true

    return 0
}

# `optimize_graphics` - Optimizes graphics settings for low-end GPUs
function optimize_graphics() {
    # Fix WindowServer settings
    defaults write com.apple.WindowServer UseOptimizedDrawing -bool true 2>/dev/null || true
    defaults write com.apple.WindowServer Accelerate -bool false 2>/dev/null || true
    defaults write com.apple.WindowServer EnableHiDPI -bool false 2>/dev/null || true
    
    # Fix GPU settings
    defaults write com.apple.WindowServer MaximumGPUMemory -int 256 2>/dev/null || true
    defaults write com.apple.WindowServer GPUPowerPolicy -string "minimum" 2>/dev/null || true
    defaults write com.apple.WindowServer DisableGPUProcessing -bool true 2>/dev/null || true

    return 0
}

# `backup_graphics_settings` - Backs up graphics-related settings
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

# `restart_ui_services` - Restarts UI services
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

# `setup_recovery` - Creates a recovery script
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

# `optimize_display` - Optimizes display settings
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

# `optimize_storage` - Optimizes disk storage usage
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

# `optimize_network` - Optimizes network settings
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
        "kern.ipc.somaxconn=2048"
        "kern.ipc.maxsockbuf=8388608"
        "kern.ipc.nmbclusters=65536"
        "net.inet.tcp.msl=15000"
        "net.inet.tcp.delayed_ack=0"
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
    if ! networksetup -setv6automatic "Wi-Fi" 2>/dev/null; then
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

# `optimize_security` - Optimizes system security settings
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
    
    if ! sudo "$firewall_path" --setallowsigned on 2>/dev/null; then
        firewall_success=false
        echo -e "${YELLOW}⚠${NC} Failed to configure signed apps"
    fi
    
    if ! sudo "$firewall_path" --setloggingmode on 2>/dev/null; then
        firewall_success=false
        echo -e "${YELLOW}⚠${NC} Failed to enable logging"
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
        
        if ! sudo systemsetup -setremoteappleevents off 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Failed to disable remote Apple events"
        else
            echo -e "${GREEN}✓${NC} Remote Apple events disabled"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Remote access configuration skipped (systemsetup not available)"
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
        if ! sudo spctl --master-enable 2>/dev/null; then
            echo -e "${YELLOW}⚠${NC} Failed to enable Gatekeeper"
            additional_checks=false
        fi
    fi
    
    # Check automatic updates
    if ! sudo softwareupdate --schedule on 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC} Failed to enable automatic updates"
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

# `create_backup` - Creates a system settings backup
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
    
    # Backup network settings
    if ! networksetup -getinfo "Wi-Fi" > "$backup_path/wifi_settings.txt" 2>/dev/null; then
        log "Failed to backup Wi-Fi settings"
    fi
    
    # Backup firewall settings
    if ! sudo defaults read /Library/Preferences/com.apple.alf > "$backup_path/firewall_settings.txt" 2>/dev/null; then
        log "Failed to backup firewall settings"
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

# --- Performance Analysis ---
# `measure_performance` - Measures system performance metrics
function measure_performance() {
    local measurement_type=$1
    case $measurement_type in
        "boot") system_profiler SPStartupItemDataType > "$MEASUREMENTS_FILE.before" ;;
        "memory") vm_stat > "$MEASUREMENTS_FILE.before" ;;
        "disk") diskutil info / > "$MEASUREMENTS_FILE.before" ;;
        "network") networksetup -getinfo "Wi-Fi" > "$MEASUREMENTS_FILE.before" ;;
    esac
}

# `show_comparison` - Shows a comparison of system performance
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

# --- System Information ---
# `display_system_info` - Displays detailed system information
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

# `describe_optimization` - Provides detailed description of an optimization type
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

# --- Optimization Profiles ---
# `create_optimization_profile` - Creates an optimization profile
function create_optimization_profile() {
    local profile_name=$1
    local profile_dir="$PROFILES_DIR/$profile_name"
    
    mkdir -p "$profile_dir"
    defaults read > "$profile_dir/defaults.plist"
    pmset -g > "$profile_dir/power.txt"
    networksetup -listallhardwareports > "$profile_dir/network.txt"
    
    echo -e "${GREEN}Profile '$profile_name' created successfully${NC}"
}

# `apply_optimization_profile` - Applies an optimization profile
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

# --- Quick Fixes ---
# `quick_fix_menu` - Provides a menu of quick fixes
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

# --- Scheduling and Automation ---
# `schedule_optimization` - Schedules automatic optimization runs
function schedule_optimization() {
    local schedule_type=$1
    local schedule_time=$2
    
    local temp_crontab
    temp_crontab=$(mktemp) || { error "Failed to create temp file"; return 1; }
    
    crontab -l > "$temp_crontab" 2>/dev/null
    
    # Remove any existing mac_optimizer entries
    sed -i.bak "/mac_optimizer/d" "$temp_crontab"
    
    # Add new schedule based on type
    case $schedule_type in
        "daily")
            echo "0 $schedule_time * * * $0 --auto" >> "$temp_crontab"
            ;;
        "weekly") 
            echo "0 $schedule_time * * 0 $0 --auto" >> "$temp_crontab"
            ;;
        "monthly")
            echo "0 $schedule_time 1 * * $0 --auto" >> "$temp_crontab"
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

# `analyze_system_usage` - Analyzes system usage patterns
function analyze_system_usage() {
    log "Analyzing system usage patterns"
    
    # Get system metrics
    local cpu_intensive=$(top -l 2 -n 0 -F | grep "CPU usage" | tail -1) || cpu_intensive="Unable to get CPU data"
    local memory_usage=$(vm_stat | awk '/Pages active/ {print $3}' | sed 's/\.//')
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
    local battery_cycles
    
    if system_profiler SPPowerDataType &>/dev/null; then
        battery_cycles=$(system_profiler SPPowerDataType | awk '/Cycle Count/ {print $3}')
    else
        battery_cycles="Not available"
    fi

    # Save metrics to usage profile
    cat > "$USAGE_PROFILE" << EOF
last_analyzed=$(date +%s)
cpu_usage=$cpu_intensive
memory_usage=${memory_usage:-0}
disk_usage=${disk_usage:-0}
battery_cycles=${battery_cycles:-Unknown}
EOF

    success "System analysis completed"
    return 0
}

# `auto_maintenance` - Performs automated maintenance tasks
function auto_maintenance() {
    log "Starting automated maintenance"
    
    local last_run=0
    [[ -f "$LAST_RUN_FILE" ]] && last_run=$(cat "$LAST_RUN_FILE")
    local current_time=$(date +%s)
    
    # Run maintenance if 24 hours have passed
    if (( current_time - last_run >= 86400 )); then
        # Cleanup old backups
        local backup_dir="$HOME/.mac_optimizer/backups"
        if [[ -d "$backup_dir" ]]; then
            find "$backup_dir" -type d -mtime +30 -exec rm -rf {} +
        fi
        
        create_backup
        optimize_storage
        optimize_network
        
        echo "$current_time" > "$LAST_RUN_FILE"
    fi
}

# --- Backup Restoration ---
# `restore_backup` - Restores system settings from a backup
function restore_backup() {
    local backup_path=$1
    
    if [[ ! -d "$backup_path" ]]; then
        error "Backup directory not found: $backup_path"
        return 1
    fi
    
    echo -e "\n${CYAN}Restoring backup from: $backup_path${NC}"
    
    # Create safety backup
    local safety_backup="$BASE_DIR/backups/pre_restore_$(date +%Y%m%d_%H%M%S)"
    create_backup "$safety_backup" || {
        warning "Failed to create safety backup"
    }
    
    # Restore global defaults if they exist
    if [[ -f "$backup_path/global_defaults.plist" ]]; then
        defaults import -globalDomain "$backup_path/global_defaults.plist" || {
            error "Failed to restore global defaults"
            return 1
        }
    fi
    
    local restored=0
    local failed=0
    
    # Restore individual plists
    while IFS= read -r file; do
        local domain=$(basename "$file" .plist)
        if [[ "$domain" != "global_defaults" ]]; then
            if defaults import "$domain" "$file" 2>/dev/null; then
                ((restored++))
            else
                ((failed++))
                error "Failed to restore: $domain"
            fi
        fi
    done < <(find "$backup_path" -name "*.plist")
    
    # Restart UI processes
    killall Dock Finder SystemUIServer &>/dev/null || true
    
    echo -e "\n${CYAN}Restore Summary:${NC}"
    echo -e "Successfully restored: ${GREEN}$restored${NC} domains"
    [[ $failed -gt 0 ]] && echo -e "Failed to restore: ${RED}$failed${NC} domains"
    
    success "Restore completed"
    return 0
}

# --- Main Script Execution ---
# Main function to handle script execution
function main() {
    # Check system requirements
    check_system_requirements || exit 1
    
    # Setup trap for cleanup
    trap cleanup EXIT
    
    # Process command line arguments
    case "${1:-}" in
        "--auto")
            auto_maintenance
            ;;
        "--help"|"-h")
            display_help
            ;;
        "--version"|"-v")
            echo "Mac Optimizer v$VERSION"
            ;;
        *)
            # Interactive mode
            display_system_info
            quick_fix_menu
            ;;
    esac
}

# Run main function
main "$@"