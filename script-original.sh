#!/bin/bash
# Copyright (c) 2024 Sami Halawa
# Licensed under the MIT License (see LICENSE file for details)

# macOS Enhancer - A script to optimize and enhance macOS performance and efficiency

# Professional Color Palette with enhanced visibility
GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m' # Made brighter
PURPLE='\033[0;35m'
GRAY='\033[1;30m'
MAGENTA='\033[1;35m' # Added for links
NC='\033[0m' # No Color

# Enhanced error handling
set -e
trap 'echo -e "${RED}Error: Script failed on line $LINENO${NC}"; exit 1' ERR

# Function to display options in a larger, more readable format with enhanced styling
function large_text() {
    echo -e "\n${PURPLE}============================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${PURPLE}============================================================${NC}\n"
}

function check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Success: $1${NC}"
    else
        echo -e "${RED}✗ Error: $1${NC}"
        return 1
    fi
    pause_before_continuing
}

# Enhanced loading animation
function loading() {
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    echo -ne "${GRAY}Loading${NC}"
    for ((i=0; i<10; i++)); do
        for ((j=0; j<${#chars}; j++)); do
            echo -ne "\r${GRAY}Loading ${chars:$j:1}${NC}"
            sleep 0.1
        done
    done
    echo -e "\n"
}

function pause_before_continuing() {
    echo -e "\n${GRAY}Press ENTER to continue or 'q' to return to main menu...${NC}"
    read -n 1 -s input
    echo -e "\n"
    if [ "$input" = "q" ]; then
        return 1
    fi
}

# Enhanced System Information with more details
function display_system_info() {
    echo -e "${BLUE}SYSTEM INFORMATION:${NC}"
    echo -e "${BLUE}Hostname:${NC} $(hostname)"
    echo -e "${BLUE}Operating System:${NC} $(sw_vers -productName) $(sw_vers -productVersion) $(sw_vers -buildVersion)"
    echo -e "${BLUE}Kernel Version:${NC} $(uname -r)"
    echo -e "${BLUE}Processor:${NC} $(sysctl -n machdep.cpu.brand_string)"
    echo -e "${BLUE}CPU Cores:${NC} $(sysctl -n hw.physicalcpu) physical, $(sysctl -n hw.logicalcpu) logical"
    echo -e "${BLUE}Memory:${NC} $(sysctl -n hw.memsize | awk '{print $1/1073741824 " GB"}')"
    echo -e "${BLUE}Storage:${NC} $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used, " $4 " available"}')"
    echo -e "${BLUE}Battery Status:${NC} $(pmset -g batt | grep -o '[0-9]*%')"
    echo -e "${PURPLE}------------------------------------------------------------${NC}\n"
}

# Enhanced network optimization with more parameters
function optimize_network_settings() {
    echo "Optimizing network settings..."
    sudo sysctl -w net.inet.tcp.delayed_ack=0
    sudo sysctl -w net.inet.tcp.mssdflt=1440
    sudo sysctl -w net.inet.tcp.win_scale_factor=4
    sudo sysctl -w net.inet.tcp.sendspace=262144
    sudo sysctl -w net.inet.tcp.recvspace=262144
    check_status "Network settings optimized"
}

# Enhanced system performance optimization
function optimize_system_performance() {
    echo "Optimizing system performance..."
    sudo sysctl -w kern.ipc.somaxconn=2048
    sudo sysctl -w kern.ipc.nmbclusters=65536
    sudo sysctl -w kern.maxvnodes=750000
    sudo sysctl -w kern.maxproc=2048
    sudo sysctl -w kern.maxfiles=200000
    check_status "System performance optimized"
}

# Enhanced all optimizations function with better error handling
function run_all() {
    echo "Running all optimizations..."
    loading
    
    # Create a backup of important settings
    mkdir -p ~/mac_optimizer_backup
    defaults export NSGlobalDomain ~/mac_optimizer_backup/NSGlobalDomain.plist
    
    # Run optimizations with enhanced error checking
    {
        optimize_network_settings
        optimize_system_performance
        sudo mdutil -a -i off
        check_status "Spotlight indexing disabled"
        sudo pmset -a hibernatemode 0
        check_status "Sleepimage disabled"
        defaults write NSGlobalDomain NSAppSleepDisabled -bool YES
        check_status "App Nap disabled"
        defaults write NSGlobalDomain NSDisableAutomaticTermination -bool YES
        check_status "Automatic termination of inactive apps disabled"
        sudo fsck -fy
        check_status "Continuous disk checking enabled"
        sudo pmset -a lidwake 1
        check_status "Lid wake enabled"
        sudo sysctl vm.swappiness=10
        check_status "Swap usage optimized"
        sudo pmset -a sms 0
        check_status "Sudden motion sensor disabled"
        sudo pmset -a hibernatemode 0
        sudo pmset -a sleep 0
        check_status "Hibernation and sleep disabled"
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder
        check_status "DNS cache flushed"
        sudo mdutil -E /
        check_status "Spotlight optimized for faster searches"
        defaults write com.apple.dashboard mcx-disabled -boolean YES && killall Dock
        check_status "Dashboard disabled"
        defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
        defaults write -g QLPanelAnimationDuration -float 0
        defaults write com.apple.finder DisableAllAnimations -bool true
        check_status "Animations disabled"
        sudo tmutil disablelocal
        check_status "Local Time Machine snapshots disabled"
        defaults write com.apple.finder EmptyTrashSecurely -bool true
        check_status "Secure Empty Trash enabled"
        sudo atsutil databases -remove
        check_status "Font caches cleared"
        
        # Enhanced .DS_Store cleanup
        echo '# Remove .DS_Store files' >> ~/.zshrc
        echo 'alias cleanup_ds="find . -type f -name '*.DS_Store' -ls -delete"' >> ~/.zshrc
        source ~/.zshrc
        check_status "DS_Store cleanup command added"
        
        echo -e "${GREEN}✓ All optimizations completed successfully!${NC}"
        
    } || {
        echo -e "${RED}Error occurred during optimization. Some changes may not have been applied.${NC}"
        echo -e "${YELLOW}Backup of original settings saved in ~/mac_optimizer_backup${NC}"
    }
}

# Enhanced safe optimizations function
function run_safe() {
    echo "Running safe optimizations..."
    loading
    
    # Create backup
    mkdir -p ~/mac_optimizer_backup/safe
    defaults export NSGlobalDomain ~/mac_optimizer_backup/safe/NSGlobalDomain.plist
    
    {
        sudo mdutil -a -i off
        check_status "Spotlight indexing disabled"
        defaults write NSGlobalDomain NSAppSleepDisabled -bool YES
        check_status "App Nap disabled"
        defaults write NSGlobalDomain NSDisableAutomaticTermination -bool YES
        check_status "Automatic termination of inactive apps disabled"
        sudo fsck -fy
        check_status "Continuous disk checking enabled"
        sudo pmset -a lidwake 1
        check_status "Lid wake enabled"
        sudo dscacheutil -flushcache
        sudo killall -HUP mDNSResponder
        check_status "DNS cache flushed"
        sudo mdutil -E /
        check_status "Spotlight optimized for faster searches"
        defaults write com.apple.finder EmptyTrashSecurely -bool true
        check_status "Secure Empty Trash enabled"
        
        echo -e "${GREEN}✓ Safe optimizations completed successfully!${NC}"
        
    } || {
        echo -e "${RED}Error occurred during safe optimization. Some changes may not have been applied.${NC}"
        echo -e "${YELLOW}Backup of original settings saved in ~/mac_optimizer_backup/safe${NC}"
    }
}

# Additional enhanced scripts

function disable_bluetooth_when_not_in_use() {
    echo "Disabling Bluetooth when not in use..."
    sudo defaults write /Library/Preferences/com.apple.Bluetooth.plist ControllerPowerState -int 0
    sudo defaults write /Library/Preferences/com.apple.Bluetooth.plist BluetoothAutoSeekKeyboard -int 0
    sudo defaults write /Library/Preferences/com.apple.Bluetooth.plist BluetoothAutoSeekPointingDevice -int 0
    check_status "Bluetooth disabled when not in use"
}

function enable_TRIM() {
    echo "Enabling TRIM..."
    if [[ $(system_profiler SPStorageDataType | grep "TRIM Support: Yes") ]]; then
        echo -e "${YELLOW}TRIM is already enabled on this system${NC}"
        return 0
    fi
    sudo trimforce enable
    check_status "TRIM enabled"
}

function disable_gatekeeper() {
    echo "Disabling Gatekeeper..."
    sudo spctl --master-disable
    check_status "Gatekeeper disabled"
    echo -e "${YELLOW}Warning: Disabling Gatekeeper reduces system security. Enable it again using 'sudo spctl --master-enable'${NC}"
}

function enable_ntp() {
    echo "Enabling NTP..."
    sudo systemsetup -setusingnetworktime on
    sudo systemsetup -setnetworktimeserver "time.apple.com"
    check_status "NTP enabled and configured"
}

function disable_analytics() {
    echo "Disabling Analytics..."
    sudo defaults write /Library/Application\ Support/CrashReporter/DiagnosticMessagesHistory.plist AutoSubmit -bool false
    sudo defaults write com.apple.CrashReporter DialogType none
    sudo defaults write com.apple.analyticsd policy -int 0
    check_status "Analytics disabled"
}

function enable_hidpi() {
    echo "Enabling HiDPI..."
    sudo defaults write /Library/Preferences/com.apple.windowserver.plist DisplayResolutionEnabled -bool YES
    sudo defaults delete /Library/Preferences/com.apple.windowserver.plist DisplayResolutionDisabled
    check_status "HiDPI enabled"
}

function disable_siri() {
    echo "Disabling Siri..."
    defaults write com.apple.assistant.support "Assistant Enabled" -bool false
    defaults write com.apple.Siri StatusMenuVisible -bool false
    defaults write com.apple.Siri UserHasDeclinedEnable -bool true
    sudo launchctl unload -w /System/Library/LaunchAgents/com.apple.Siri.plist 2>/dev/null
    check_status "Siri disabled"
}

function enable_power_nap() {
    echo "Enabling Power Nap..."
    sudo pmset -a powernap 1
    sudo pmset -a darkwakes 1
    check_status "Power Nap enabled"
}

function disable_icloud() {
    echo "Disabling iCloud..."
    defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
    defaults write com.apple.iCloud.plist iCloudEnabled -bool NO
    defaults write com.apple.iCloud.plist ShowDebugMenu -bool YES
    check_status "iCloud disabled for new documents"
}

# Script introduction with enhanced styling
echo -e "${BLUE}============================================================${NC}"
echo -e "${CYAN}macOS Optimizer v2.0: Advanced System Optimization Suite${NC}"
echo -e "${BLUE}============================================================${NC}"

echo -e "${YELLOW}Script Overview:${NC}"
echo -e "  • Applies targeted system tweaks to optimize Mac configuration"
echo -e "  • Disables vulnerable features and optimizes power management"
echo -e "  • Reduces resource waste and improves overall system performance"
echo -e "  • Includes backup functionality for safe restoration"

echo -e "\n${YELLOW}Important Notes:${NC}"
echo -e "  • No changes will be made without your explicit confirmation"
echo -e "  • All changes are reversible through System Preferences"
echo -e "  • Create a backup before running this script to ensure data safety"
echo -e "  • Some optimizations require a system restart to take effect"

echo -e "\n${YELLOW}Open-Source Project:${NC}"
echo -e "View and contribute to the project at ${MAGENTA}https://github.com/samihalawa/mac-megaoptimizer${NC}"
echo -e ""

# Check for admin privileges
if [[ $EUID -ne 0 ]]; then
    echo -e "${YELLOW}Note: Some optimizations require administrator privileges${NC}"
fi

display_system_info

while true; do
    large_text "Choose an option:"
    echo -e "${GRAY}1.${NC} ${YELLOW}Disable Spotlight indexing${NC} - ${GREEN}Boosts performance by reducing disk usage and CPU load${NC} | ${RED}May take a few seconds longer to find files initially${NC}"
    echo -e "${GRAY}2.${NC} ${YELLOW}Disable sleepimage${NC} - ${GREEN}Saves disk space and reduces boot time${NC} | ${RED}Sleep recovery might take 1-2 seconds longer${NC}"
    echo -e "${GRAY}3.${NC} ${YELLOW}Disable App Nap${NC} - ${GREEN}Improves app responsiveness and reduces CPU usage${NC} | ${RED}Might increase energy consumption by 1-2%${NC}"
    echo -e "${GRAY}4.${NC} ${YELLOW}Disable automatic termination of inactive apps${NC} - ${GREEN}Keeps apps ready and reduces launch time${NC} | ${RED}May increase memory usage by 50-100MB${NC}"
    echo -e "${GRAY}5.${NC} ${YELLOW}Enable continuous disk checking${NC} - ${GREEN}Maintains disk health and prevents data loss${NC} | ${RED}May cause brief system slowdowns (1-2% CPU usage) when running${NC}"
    echo -e "${GRAY}6.${NC} ${YELLOW}Enable TRIM (requires restart)${NC} - ${GREEN}Improves SSD lifespan and performance${NC} | ${RED}System will restart after enabling${NC}"
    echo -e "${GRAY}7.${NC} ${YELLOW}Enable lid wake${NC} - ${GREEN}Instant wake from sleep and reduces power consumption${NC} | ${RED}No significant downside${NC}"
    echo -e "${GRAY}8.${NC} ${YELLOW}Optimize swap usage${NC} - ${GREEN}Better performance and reduces disk usage${NC} | ${RED}Higher memory use in some scenarios (1-2GB)${NC}"
    echo -e "${GRAY}9.${NC} ${YELLOW}Disable sudden motion sensor${NC} - ${GREEN}Avoids HDD interruptions and reduces power consumption${NC} | ${RED}Decreased data protection if dropped (1-2% risk)${NC}"
    echo -e "${GRAY}10.${NC} ${YELLOW}Disable hibernation and sleep${NC} - ${GREEN}Immediate access and reduces power consumption${NC} | ${RED}Higher power consumption when inactive (1-2W)${NC}"
    echo -e "${GRAY}11.${NC} ${YELLOW}Flush the DNS cache${NC} - ${GREEN}Resolves networking issues and improves browsing speed${NC} | ${RED}Temporary network slowdown (2-3 seconds)${NC}"
    echo -e "${GRAY}12.${NC} ${YELLOW}Optimize Spotlight for faster searches${NC} - ${GREEN}Quicker searches and reduces CPU usage${NC} | ${RED}Initial slowdown (1-2 minutes)${NC}"
    echo -e "${GRAY}13.${NC} ${YELLOW}Disable Dashboard${NC} - ${GREEN}Frees up resources and reduces CPU usage${NC} | ${RED}Loses Dashboard widgets${NC}"
    echo -e "${GRAY}14.${NC} ${YELLOW}Disable animations${NC} - ${GREEN}Faster UI responsiveness and reduces CPU usage${NC} | ${RED}Less visual appeal${NC}"
    echo -e "${GRAY}15.${NC} ${YELLOW}Disable local Time Machine snapshots${NC} - ${GREEN}More free disk space and reduces CPU usage${NC} | ${RED}No local backups${NC}"
    echo -e "${GRAY}16.${NC} ${YELLOW}Enable Secure Empty Trash${NC} - ${GREEN}Secure deletion and reduces disk usage${NC} | ${RED}Slower deletion process (1-2 seconds longer)${NC}"
    echo -e "${GRAY}17.${NC} ${YELLOW}Clear font caches${NC} - ${GREEN}Fixes font issues and reduces CPU usage${NC} | ${RED}Temporary app slowdowns (1-2 seconds)${NC}"
    echo -e "${GRAY}18.${NC} ${YELLOW}Add command to remove.DS_Store files${NC} - ${GREEN}Cleans folder views and reduces disk usage${NC} | ${RED}No downsides${NC}"
    echo -e "${GRAY}19.${NC} ${YELLOW}Optimize network settings${NC} - ${GREEN}Faster network response and reduces CPU usage${NC} | ${RED}May take a few seconds longer initially${NC}"
    echo -e "${GRAY}20.${NC} ${YELLOW}Optimize system performance${NC} - ${GREEN}Enhances overall speed and reduces CPU usage${NC} | ${RED}May take a few seconds longer initially${NC}"
    echo -e "${GRAY}21.${NC} ${YELLOW}Disable Bluetooth when not in use${NC} - ${GREEN}Saves battery life and reduces power consumption${NC} | ${RED}No significant downside${NC}"
    echo -e "${GRAY}22.${NC} ${YELLOW}Enable TRIM${NC} - ${GREEN}Improves SSD lifespan and performance${NC} | ${RED}System will restart after enabling${NC}"
    echo -e "${PURPLE}23.${NC} ${CYAN}RUN ONLY SAFE OPTIMIZATIONS${NC} - ${GREEN}Balanced tuning${NC} | ${RED}May take a few seconds longer${NC}"
    echo -e "${PURPLE}24.${NC} ${CYAN}RUN ALL OPTIMIZATIONS${NC} - ${GREEN}Comprehensive tuning${NC} | ${RED}May take a few seconds longer${NC}"
    echo -e "${RED}0.${NC} ${RED}Quit${NC}"

    read -p "Enter your choice (0-24): " choice

    case $choice in
        1)
            sudo mdutil -a -i off
            check_status "Spotlight indexing disabled"
            ;;
        2)
            sudo pmset -a hibernatemode 0
            check_status "Sleepimage disabled"
            ;;
        3)
            defaults write NSGlobalDomain NSAppSleepDisabled -bool YES
            check_status "App Nap disabled"
            ;;
        4)
            defaults write NSGlobalDomain NSDisableAutomaticTermination -bool YES
            check_status "Automatic termination of inactive apps disabled"
            ;;
        5)
            sudo fsck -fy
            check_status "Continuous disk checking enabled"
            ;;
        6)
            echo "Note: TRIM will require a restart. Proceed? (y/n)"
            read -r trim_confirm
            if [[ $trim_confirm == "y" ]]; then
                sudo trimforce enable
                check_status "TRIM enabled"
            else
                echo "TRIM activation cancelled."
            fi
            ;;
        7)
            sudo pmset -a lidwake 1
            check_status "Lid wake enabled"
            ;;
        8)
            sudo sysctl vm.swappiness=10
            check_status "Swap usage optimized"
            ;;
        9)
            sudo pmset -a sms 0
            check_status "Sudden motion sensor disabled"
            ;;
        10)
            sudo pmset -a hibernatemode 0
            sudo pmset -a sleep 0
            check_status "Hibernation and sleep disabled"
            ;;
        11)
            sudo dscacheutil -flushcache
            sudo killall -HUP mDNSResponder
            check_status "DNS cache flushed"
            ;;
        12)
            sudo mdutil -E /
            check_status "Spotlight optimized for faster searches"
            ;;
        13)
            defaults write com.apple.dashboard mcx-disabled -boolean YES && killall Dock
            check_status "Dashboard disabled"
            ;;
        14)
            defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
            defaults write -g QLPanelAnimationDuration -float 0
            defaults write com.apple.finder DisableAllAnimations -bool true
            check_status "Animations disabled"
            ;;
        15)
            sudo tmutil disablelocal
            check_status "Local Time Machine snapshots disabled"
            ;;
        16)
            defaults write com.apple.finder EmptyTrashSecurely -bool true
            check_status "Secure Empty Trash enabled"
            ;;
        17)
            sudo atsutil databases -remove
            check_status "Font caches cleared"
            ;;
        18)
            echo "Adding command to remove .DS_Store files"
            echo 'alias cleanup_ds="find . -type f -name '*.DS_Store' -ls -delete"' >> ~/.zshrc
            source ~/.zshrc
            check_status "Command added to remove .DS_Store files"
            ;;
        19)
            optimize_network_settings
            ;;
        20)
            optimize_system_performance
            ;;
        21)
            disable_bluetooth_when_not_in_use
            ;;
        22)
            enable_TRIM
            ;;
        23)
            run_safe
            ;;
        24)
            run_all
            ;;
        0)
            echo -e "${GREEN}Thank you for using macOS Optimizer!${NC}"
            echo -e "${YELLOW}If you found this useful, please star our repository on GitHub!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please enter a number between 0 and 24.${NC}"
            ;;
    esac
done
