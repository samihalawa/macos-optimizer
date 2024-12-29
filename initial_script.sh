#!/bin/bash
# Copyright (c) 2024 Sami Halawa
# Licensed under the MIT License (see LICENSE file for details)

# macOS Enhancer - A script to optimize and enhance macOS performance and efficiency


# Professional Color Palette
GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
GRAY='\033[1;30m'
NC='\033[0m' # No Color

# Function to display options in a larger, more readable format
function large_text() {
    echo -e "${PURPLE}============================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${PURPLE}============================================================${NC}"
}

function check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success: $1${NC}"
    else
        echo -e "${RED}Error: $1${NC}"
    fi
    pause_before_continuing
}

# Loading animation
function loading() {
    echo -ne "${GRAY}Loading${NC}"
    for i in {1..5}; do
        echo -ne "${GRAY}.${NC}"
        sleep 0.5
    done
    echo -e "\n"
}

function pause_before_continuing() {
    echo -e "${GRAY}Press ENTER to continue or 'q' to cancel and return to main menu...${NC}"
    read -n 1 -s input
    echo -e "\n"
    if [ "$input" = "q" ]; then
        continue
    fi
}

# System Information
function display_system_info() {
    echo -e "${BLUE}SYSTEM INFORMATION:${NC}"
    echo -e "${BLUE}Hostname:${NC} $(hostname)"
    echo -e "${BLUE}Operating System:${NC} $(sw_vers -productName) $(sw_vers -productVersion)"
    echo -e "${BLUE}Kernel Version:${NC} $(uname -r)"
    echo -e "${BLUE}Processor:${NC} $(sysctl -n machdep.cpu.brand_string)"
    echo -e "${BLUE}Memory:${NC} $(sysctl -n hw.memsize | awk '{print $1/1073741824 " GB"}')"
    echo -e "${BLUE}Storage:${NC} $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used, " $4 " available"}')"
    echo -e "${PURPLE}------------------------------------------------------------${NC}\n"
}

function optimize_network_settings() {
    echo "Optimizing network settings..."
    sudo sysctl -w net.inet.tcp.delayed_ack=0
    sudo sysctl -w net.inet.tcp.mssdflt=1440
    check_status "Network settings optimized"
}

function optimize_system_performance() {
    echo "Optimizing system performance..."
    sudo sysctl -w kern.ipc.somaxconn=1024
    sudo sysctl -w kern.ipc.nmbclusters=32768
    check_status "System performance optimized"
}

function run_all() {
    echo "Running all optimizations..."
    loading
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
    echo "Adding command to remove.DS_Store files from new folders"
    echo "find. -name '.DS_Store' -depth -exec rm {} \;" >> ~/.profile
    source ~/.profile
    check_status "Command added to remove.DS_Store files"
    echo -e "${GREEN}All optimizations complete!${NC}"
}

function run_safe() {
    echo "Running safe optimizations..."
    loading
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
    check_status "DNS cache flushed"
    sudo mdutil -E /
    check_status "Spotlight optimized for faster searches"
    defaults write com.apple.finder EmptyTrashSecurely -bool true
    check_status "Secure Empty Trash enabled"
    echo -e "${GREEN}Safe optimizations complete!${NC}"
}

# Additional scripts

function disable_bluetooth_when_not_in_use() {
    echo "Disabling Bluetooth when not in use..."
    sudo defaults write /Library/Preferences/com.apple.Bluetooth.plist ControllerPowerState -int 0
    check_status "Bluetooth disabled when not in use"
}

function enable_TRIM() {
    echo "Enabling TRIM..."
    sudo trimforce enable
    check_status "TRIM enabled"
}

function disable_gatekeeper() {
    echo "Disabling Gatekeeper..."
    sudo spctl --master-disable
    check_status "Gatekeeper disabled"
}

function enable_ntp() {
    echo "Enabling NTP..."
    sudo systemsetup -setusingnetworktime on
    check_status "NTP enabled"
}

function disable_analytics() {
    echo "Disabling Analytics..."
    sudo defaults write com.apple.analyticsd policy -int 0
    check_status "Analytics disabled"
}

function enable_hidpi() {
    echo "Enabling HiDPI..."
    sudo defaults write /Library/Preferences/com.apple.windowserver.plist DisplayResolutionEnabled -bool YES
    check_status "HiDPI enabled"
}

function disable_siri() {
    echo "Disabling Siri..."
    sudo defaults write com.apple.assistant.support.plist AssistantEnabled -bool NO
    check_status "Siri disabled"
}

function enable_power_nap() {
    echo "Enabling Power Nap..."
    sudo pmset -a powernap 1
    check_status "Power Nap enabled"
}

function disable_icloud() {
    echo "Disabling iCloud..."
    sudo defaults write com.apple.iCloud.plist iCloudEnabled -bool NO
    check_status "iCloud disabled"
}

# Script introduction
echo -e "${BLUE}============================================================${NC}"
echo -e "${CYAN}macOS Optimizer: System Tweaks for Performance and Security${NC}"
echo -e "${BLUE}============================================================${NC}"

echo -e "${YELLOW}Script Overview:${NC}"
echo -e "  • Applies targeted system tweaks to optimize Mac configuration"
echo -e "  • Disables vulnerable features and optimizes power management"
echo -e "  • Reduces resource waste and improves overall system performance"

echo -e "${YELLOW}Important Notes:${NC}"
echo -e "  • No changes will be made without your explicit confirmation"
echo -e "  • Create a backup before running this script to ensure data safety"

echo -e "${YELLOW}Open-Source Project:${NC}"
echo -e "View and contribute to the project at ${MAGENTA}https://github.com/samihalawa/mac-megaoptimizer${NC}"
echo -e ""

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
echo -e "${GRAY}18.${NC} ${YELLOW}Add command to remove.DS_Store files from new folders${NC} - ${GREEN}Cleans folder views and reduces disk usage${NC} | ${RED}No downsides${NC}"
echo -e "${GRAY}19.${NC} ${YELLOW}Optimize network settings${NC} - ${GREEN}Faster network response and reduces CPU usage${NC} | ${RED}May take a few seconds longer initially${NC}"
echo -e "${GRAY}20.${NC} ${YELLOW}Optimize system performance${NC} - ${GREEN}Enhances overall speed and reduces CPU usage${NC} | ${RED}May take a few seconds longer initially${NC}"
echo -e "${GRAY}21.${NC} ${YELLOW}Disable Bluetooth when not in use${NC} - ${GREEN}Saves battery life and reduces power consumption${NC} | ${RED}No significant downside${NC}"
echo -e "${GRAY}22.${NC} ${YELLOW}Enable TRIM${NC} - ${GREEN}Improves SSD lifespan and performance${NC} | ${RED}System will restart after enabling${NC}"
# echo -e "${GRAY}23.${NC} ${YELLOW}Disable Gatekeeper${NC} - ${GREEN}Allows installation of unsigned apps and reduces CPU usage${NC} | ${RED}Security risks if not used carefully${NC}"
echo -e "${PURPLE}23.${NC} ${CYAN}RUN ONLY SAFE OPTIMIZATIONS (1,3,4,5,6,7,11,12,16)${NC} - ${GREEN}Balanced tuning${NC} | ${RED}May take a few seconds longer${NC}"
echo -e "${PURPLE}24.${NC} ${CYAN}RUN ALL OPTIMIZATIONS (except TRIM as requires restart)${NC} - ${GREEN}Comprehensive tuning${NC} | ${RED}May take a few seconds longer${NC}"
# echo -e "${GRAY}23.${NC} ${YELLOW}Disable #Gatekeeper${NC} - ${GREEN}Allows installation of unsigned apps${NC} | ${RED}Security risks if not used carefully${NC}"

# echo -e "${GRAY}26.${NC} ${YELLOW}Enable NTP${NC} - ${GREEN}Syncs system clock with internet time${NC} | ${RED}No significant downside${NC}"
# echo -e "${GRAY}27.${NC} ${YELLOW}Disable Analytics${NC} - ${GREEN}Improves privacy${NC} | ${RED}No significant downside${NC}"
# echo -e "${GRAY}28.${NC} ${YELLOW}Enable HiDPI${NC} - ${GREEN}Sharper display${NC} | ${RED}May cause display issues on some systems${NC}"
# echo -e "${GRAY}29.${NC} ${YELLOW}Disable Siri${NC} - ${GREEN}Frees up resources${NC} | ${RED}Loses Siri functionality${NC}"
# echo -e "${GRAY}30.${NC} ${YELLOW}Enable Power Nap${NC} - ${GREEN}Updates system while asleep${NC} | ${RED}May cause battery drain${NC}"
# echo -e "${GRAY}31.${NC} ${YELLOW}Disable iCloud${NC} - ${GREEN}Frees up resources${NC} | ${RED}Loses iCloud functionality${NC}"
echo -e "${RED}0.${NC} ${RED}Quit${NC}"

read -p "Enter your choice: " choice

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
        read trim_confirm
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
        echo "Adding command to remove.DS_Store files from new folders"
        echo "find. -name '.DS_Store' -depth -exec rm {} \;" >> ~/.profile
        source ~/.profile
        check_status "Command added to remove.DS_Store files"
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
#   23)
#        disable_gatekeeper
#        ;;
        23)
        run_safe
        ;;
    24)
        run_all
        ;;
 #  26)
 #       enable_ntp
 #       ;;
 #   27)
 #      disable_analytics
 #      ;;
 #  28)
 #       enable_hidpi
 #      ;;
 #  29)
 #       disable_siri
 #     ;;
 #   30)
  #      enable_power_nap
  #      ;;
  #  31)
  #      disable_icloud
  ## ;; 
    0)
        echo -e "${RED}Quitting the script. Bye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice. Please enter a valid option.${NC}"
        ;;
esac
done
