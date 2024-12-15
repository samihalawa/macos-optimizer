#!/bin/bash
# Copyright (c) 2024 Sami Halawa
# Licensed under the MIT License (see LICENSE file for details)

# macOS Enhancer - A script to optimize and enhance macOS performance and efficiency

# Color Palette
GREEN='\033[1;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
PURPLE='\033[0;35m'
GRAY='\033[1;30m'
NC='\033[0m'

# Functions
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

function loading() {
    echo -ne "${GRAY}Loading${NC}"
    for i in {1..5}; do
        echo -ne "${GRAY}.${NC}"
        sleep 0.3 # Reduced sleep time for faster loading
    done
    echo -e "\n"
}

function pause_before_continuing() {
    read -r -p "${GRAY}Press ENTER to continue or 'q' to cancel...${NC}" input
    echo "" # Add a newline for better formatting
    if [[ "$input" == "q" ]]; then
        return 1 # Return 1 to indicate cancellation
    fi
    return 0 # Return 0 to indicate continuation

}

function display_system_info() {
    echo -e "${BLUE}SYSTEM INFORMATION:${NC}"
    echo -e "${BLUE}Hostname:${NC} $(hostname)"
    echo -e "${BLUE}Operating System:${NC} $(sw_vers -productName) $(sw_vers -productVersion)"
    echo -e "${BLUE}Kernel Version:${NC} $(uname -r)"
    echo -e "${BLUE}Processor:${NC} $(sysctl -n machdep.cpu.brand_string)"
    echo -e "${BLUE}Memory:${NC} $(sysctl -n hw.memsize | awk '{printf "%.2f GB\n", $1/1073741824}')" # Formatted output
    echo -e "${BLUE}Storage:${NC} $(df -h / | awk 'NR==2 {print $2 " total, " $3 " used, " $4 " available"}')"
    echo -e "${PURPLE}------------------------------------------------------------${NC}\n"
}

# Optimizations (grouped and improved)

function optimize_storage() {
    echo "Optimizing storage..."
    sudo mdutil -a -i off # Disable indexing
    check_status "Spotlight indexing disabled"
    sudo tmutil disablelocal # Disable local Time Machine snapshots
    check_status "Local Time Machine snapshots disabled"
    defaults write com.apple.finder EmptyTrashSecurely -bool true # Secure Empty Trash
    check_status "Secure Empty Trash enabled"
    sudo atsutil databases -remove # Clear font caches
    check_status "Font caches cleared"
    echo "Adding command to remove .DS_Store files (new folders)"
    echo "find . -name '.DS_Store' -depth -exec rm {} \; 2>/dev/null" >> ~/.zshrc # Using zshrc if available or bash profile
    if [[ -f ~/.zshrc ]]; then
        source ~/.zshrc
    else
        echo "find . -name '.DS_Store' -depth -exec rm {} \; 2>/dev/null" >> ~/.bash_profile
        source ~/.bash_profile
    fi

    check_status "Command added to remove .DS_Store files"
}

function optimize_graphics() {
    echo "Optimizing graphics..."
    defaults write NSGlobalDomain NSAutomaticWindowAnimationsEnabled -bool false
    defaults write -g QLPanelAnimationDuration -float 0
    defaults write com.apple.finder DisableAllAnimations -bool true
    check_status "Animations disabled"
    defaults write com.apple.dashboard mcx-disabled -boolean YES && killall Dock
    check_status "Dashboard disabled"
    defaults write NSGlobalDomain ReduceTransparency -bool true #Reduce Transparency
    check_status "Transparency reduced"
}

function optimize_system() {
    echo "Optimizing system..."
    sudo sysctl -w kern.ipc.somaxconn=1024
    sudo sysctl -w kern.ipc.nmbclusters=32768
    sudo sysctl vm.swappiness=10
    check_status "System performance and swap usage optimized"
    sudo pmset -a lidwake 1
    check_status "Lid wake enabled"
    defaults write NSGlobalDomain NSAppSleepDisabled -bool YES
    check_status "App Nap disabled"
    defaults write NSGlobalDomain NSDisableAutomaticTermination -bool YES
    check_status "Automatic termination of inactive apps disabled"
    sudo fsck -fy
    check_status "File system check done."
    sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
    check_status "DNS cache flushed"
    sudo mdutil -E /
    check_status "Spotlight reindexed"
    sudo pmset -a sms 0
    check_status "Sudden motion sensor disabled"
    sudo pmset -a hibernatemode 0
    sudo pmset -a sleep 0
    check_status "Hibernation and sleep disabled"

}

function optimize_network() {
    echo "Optimizing network..."
    sudo sysctl -w net.inet.tcp.delayed_ack=0
    sudo sysctl -w net.inet.tcp.mssdflt=1440
    check_status "Network settings optimized"
}

function enable_trim() {
    echo "Enabling TRIM (requires restart). Proceed? (y/n)"
    read trim_confirm
    if [[ "$trim_confirm" == "y" ]]; then
        sudo trimforce enable
        check_status "TRIM enabled"
    else
        echo "TRIM activation cancelled."
    fi
}

# Main Menu
display_system_info

while true; do
    large_text "Choose an option:"
    echo -e "${GRAY}1.${NC} ${YELLOW}Optimize Storage${NC}"
    echo -e "${GRAY}2.${NC} ${YELLOW}Optimize Graphics${NC}"
    echo -e "${GRAY}3.${NC} ${YELLOW}Optimize System${NC}"
    echo -e "${GRAY}4.${NC} ${YELLOW}Optimize Network${NC}"
    echo -e "${GRAY}5.${NC} ${YELLOW}Enable TRIM (requires restart)${NC}"
    echo -e "${PURPLE}6.${NC} ${CYAN}RUN ALL OPTIMIZATIONS (Except TRIM)${NC}"
    echo -e "${RED}0.${NC} ${RED}Quit${NC}"

    read -p "Enter your choice: " choice

    case $choice in
        1) optimize_storage ;;
        2) optimize_graphics ;;
        3) optimize_system ;;
        4) optimize_network ;;
        5) enable_trim ;;
        6)
            loading
            optimize_storage
            optimize_graphics
            optimize_system
            optimize_network
            echo -e "${GREEN}All optimizations (except TRIM) complete!${NC}"
            ;;
        0)
            echo -e "${RED}Quitting...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice.${NC}"
            ;;
    esac
done