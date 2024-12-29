import subprocess
import os
import datetime
import re
import platform
import shutil
import time
from nicegui import ui, app
from typing import List, Tuple
import asyncio
import traceback
import logging
import sys

VERSION = "2.1"
BASE_DIR = os.path.expanduser("~/.mac_optimizer")
BACKUP_DIR = os.path.join(BASE_DIR, "backups", datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
LOG_FILE = os.path.join(BACKUP_DIR, "optimizer.log")
SETTINGS_FILE = os.path.join(BASE_DIR, "settings")
MIN_MACOS_VERSION = "10.15"
PROFILES_DIR = os.path.join(BASE_DIR, "profiles")
MEASUREMENTS_FILE = os.path.join(BACKUP_DIR, "performance_measurements.txt")
SCHEDULE_FILE = os.path.join(BASE_DIR, "schedule")
USAGE_PROFILE = os.path.join(BASE_DIR, "usage")
AUTO_BACKUP_LIMIT = 5
LAST_RUN_FILE = os.path.join(BASE_DIR, "lastrun")
TRACKED_DOMAINS = [
    "com.apple.dock",
    "com.apple.finder",
    "com.apple.universalaccess",
    "com.apple.WindowManager",
    "com.apple.QuickLookUI",
    "NSGlobalDomain",
]

IS_APPLE_SILICON = False
IS_ROSETTA = False
MACOS_VERSION = ""
MACOS_BUILD = ""
ARCH = platform.machine()

# Check if system_profiler is available
if shutil.which("system_profiler") is None:
    print("system_profiler command not found. This script requires macOS.")
    exit(1)

GPU_INFO = subprocess.getoutput("system_profiler SPDisplaysDataType 2>/dev/null")

# Color definitions
GREEN = '\033[1;32m'
RED = '\033[0;31m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
YELLOW = '\033[0;33m'
PURPLE = '\033[0;35m'
GRAY = '\033[1;30m'
NC = '\033[0m'
BOLD = '\033[1m'
DIM = '\033[2m'
UNDERLINE = '\033[4m'

# System detection
if ARCH == "arm64":
    IS_APPLE_SILICON = True
elif ARCH == "x86_64":
    try:
        if int(subprocess.getoutput("sysctl -n sysctl.proc_translated")) > 0:
            IS_ROSETTA = True
            IS_APPLE_SILICON = True
    except:
        pass

MACOS_VERSION = subprocess.getoutput("sw_vers -productVersion").replace("a", "").replace("b", "").replace("c", "").replace("d", "").replace("e", "").replace("f", "").replace("g", "").replace("h", "").replace("i", "").replace("j", "").replace("k", "").replace("l", "").replace("m", "").replace("n", "").replace("o", "").replace("p", "").replace("q", "").replace("r", "").replace("s", "").replace("t", "").replace("u", "").replace("v", "").replace("w", "").replace("x", "").replace("y", "").replace("z", "")
MACOS_BUILD = subprocess.getoutput("sw_vers -buildVersion")

# Enhanced logging
def enhanced_logging(severity: str, message: str, log_file: str = LOG_FILE):
    log_dir = os.path.dirname(LOG_FILE)
    os.makedirs(log_dir, exist_ok=True)
    if os.path.exists(LOG_FILE) and os.stat(LOG_FILE).st_size > 1048576:
        shutil.move(LOG_FILE, LOG_FILE + ".old")
    timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    with open(LOG_FILE, "a") as f:
        f.write(f"[{timestamp}][{severity}] {message}\n")
    print(f"{GRAY}[{severity}] {message}{NC}")

def log(message: str):
    enhanced_logging("INFO", message)
    
def error(message: str):
    enhanced_logging("ERROR", message)

def warning(message: str):
    enhanced_logging("WARNING", message)

def success(message: str):
    enhanced_logging("SUCCESS", message)

# Error handling
def handle_error(error_msg: str, error_code: int = 1):
    print(f"{RED}Error: {error_msg} (Code: {error_code}){NC}")
    log(f"ERROR: {error_msg} (Code: {error_code})")
    if error_code == 1:
        warning("Trying to elevate privileges...")
        subprocess.run(["sudo", "-v"], check=False)
    elif error_code == 2:
        warning("Waiting for resource to be available...")
        time.sleep(5)
    else:
        warning("Unknown error occurred")
    return error_code

# Memory pressure check
def memory_pressure() -> Tuple[str, int]:
    try:
        memory_stats = subprocess.getoutput("vm_stat")
        active = int(next(line.split()[2].replace('.', '') for line in memory_stats.splitlines() if "Pages active" in line))
        wired = int(next(line.split()[3].replace('.', '') for line in memory_stats.splitlines() if "Pages wired" in line))
        compressed = int(next(line.split()[4].replace('.', '') for line in memory_stats.splitlines() if "Pages occupied by compressor" in line))
        free = int(next(line.split()[2].replace('.', '') for line in memory_stats.splitlines() if "Pages free" in line))
        used = active + wired + compressed
        total = used + free
        percentage = (used * 100) // total
        return f"System memory pressure: {percentage}", 0
    except Exception as e:
        return "System memory pressure: Unable to calculate", 1

# System state verification
def verify_system_state() -> bool:
    checks_passed = True
    issues = []

    # Disk verification
    print("Checking disk health...", end="")
    if subprocess.run(["diskutil", "verifyVolume", "/"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        warning("Disk verification skipped - volume is mounted")
        print(f" {YELLOW}⚠{NC}")
    else:
        print(f" {GREEN}✓{NC}")

    # Memory check
    print("Checking memory pressure...", end="")
    mem_pressure_str, mem_pressure_code = memory_pressure()
    mem_pressure = int(mem_pressure_str.split(": ")[1].replace("%", "")) if ":" in mem_pressure_str and mem_pressure_str.split(": ")[1].replace("%", "").isdigit() else 0
    if mem_pressure > 80:
        issues.append(f"High memory pressure detected: {mem_pressure}%")
        checks_passed = False
        print(f" {RED}✗{NC}")
    else:
        print(f" {GREEN}✓{NC}")

    # CPU thermal check
    print("Checking CPU temperature...", end="")
    if subprocess.run(["sysctl", "machdep.xcpm.cpu_thermal_level"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        print(f" {YELLOW}⚠{NC} (Not available)")
    elif "1" in subprocess.getoutput("sysctl machdep.xcpm.cpu_thermal_level"):
        issues.append("CPU thermal throttling detected")
        checks_passed = False
        print(f" {RED}✗{NC}")
    else:
        print(f" {GREEN}✓{NC}")

    return checks_passed

# Version comparison
def version_compare(v1: str, v2: str) -> int:
    v1_parts = list(map(int, v1.split(".")))
    v2_parts = list(map(int, v2.split(".")))
    for i in range(max(len(v1_parts), len(v2_parts))):
        v1_part = v1_parts[i] if i < len(v1_parts) else 0
        v2_part = v2_parts[i] if i < len(v2_parts) else 0
        if v1_part > v2_part:
            return 1
        elif v1_part < v2_part:
            return 2
    return 0

# Cleanup function
def cleanup():
    print(f"\n{GRAY}Cleaning up...{NC}")
    subprocess.run(["tput", "cnorm"], check=False, stderr=subprocess.DEVNULL)
    temp_files = [
        "/tmp/mac_optimizer_temp",
        "/tmp/mac_optimizer_cleanup",
        "/private/tmp/mac_optimizer_*"
    ]
    for file in temp_files:
        if os.path.exists(file):
            try:
                shutil.rmtree(file)
            except:
                warning(f"Failed to remove {file}")
    subprocess.run(["killall", "System Preferences"], check=False, stderr=subprocess.DEVNULL)
    if os.path.exists("/tmp/mac_optimizer_ui_modified"):
        subprocess.run(["killall", "Finder", "Dock"], check=False, stderr=subprocess.DEVNULL)
        try:
            os.remove("/tmp/mac_optimizer_ui_modified")
        except:
            pass

# System requirements check
def check_system_requirements():
    major_version = int(MACOS_VERSION.split(".")[0])
    if major_version >= 11 or MACOS_VERSION.startswith("10.15"):
        return
    error(f"This script requires macOS {MIN_MACOS_VERSION} or later (detected: {MACOS_VERSION})")
    exit(1)

# Progress bar with spinner
def show_progress_bar(current: int, total: int, title: str):
    width = 50
    spinner = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
    spin_idx = 0
    percent = (current * 100) // total
    filled = (current * width) // total
    empty = width - filled
    print(f"\r{CYAN}{spinner[spin_idx]}{NC} {title} [", end="")
    print(f"{'█' * filled}{'░' * empty}", end="")
    print(f"] {percent}%", end="")
    if current == total:
        print(f"\n{GREEN}✓ Complete!{NC}\n")

# Progress tracking (using dialog)
def track_progress(current: int, total: int, message: str):
    percent = (current * 100) // total
    subprocess.run(["dialog", "--gauge", message, "8", "70", str(percent)], check=False)

# Spinner for operations without clear progress
def show_spinner(message: str, pid: int):
    spin = '-\|/'
    i = 0
    while True:
        if subprocess.run(["kill", "-0", str(pid)], stderr=subprocess.DEVNULL).returncode != 0:
            break
        print(f"\r{CYAN}{spin[i % 4]}{NC} {message}...", end="")
        time.sleep(0.1)
        i += 1
    print(f"\r{GREEN}✓{NC} {message}... Done")

# System performance optimization
def optimize_system_performance():
    log("Starting system performance optimization")
    print(f"\n{CYAN}Detailed System Performance Optimization Progress:{NC}")
    changes_made = []
    total_steps = 12
    current_step = 0

    # 1. Kernel Parameter Optimization
    print(f"\n{BOLD}1. Kernel Parameter Optimization:{NC}")
    sysctl_params = [
        "kern.maxvnodes=750000",
        "kern.maxproc=4096",
        "kern.maxfiles=524288",
        "kern.ipc.somaxconn=4096",
        "kern.ipc.maxsockbuf=8388608",
        "kern.ipc.nmbclusters=65536",
    ]
    for param in sysctl_params:
        current_step += 1
        print(f"  {HOURGLASS} Setting {param}...", end="")
        if subprocess.run(["sudo", "sysctl", "-w", param], stderr=subprocess.DEVNULL).returncode == 0:
            changes_made.append(f"Kernel parameter {param} set")
            print(f"\r  {GREEN}✓{NC} {param} applied")
        else:
            print(f"\r  {RED}✗{NC} Failed to set {param}")
        show_progress(current_step, total_steps)

    # 2. Performance Mode Settings
    print(f"\n{BOLD}2. Performance Mode Settings:{NC}")
    current_step += 1
    print(f"  {HOURGLASS} Setting maximum performance mode...", end="")
    if subprocess.run(["sudo", "pmset", "-a", "highperf", "1"], stderr=subprocess.DEVNULL).returncode == 0:
        changes_made.append("High performance mode enabled")
        print(f"\r  {GREEN}✓{NC} Maximum performance mode set")
    else:
        print(f"\r  {RED}✗{NC} Failed to set performance mode")
    show_progress(current_step, total_steps)

    # 3. CPU and Memory Optimization
    print(f"\n{BOLD}3. CPU and Memory Optimization:{NC}")
    current_step += 1
    print(f"  {HOURGLASS} Optimizing CPU settings...", end="")
    if subprocess.run(["sudo", "nvram", "boot-args=serverperfmode=1 $(nvram boot-args 2>/dev/null | cut -f 2-)"], shell=True, stderr=subprocess.DEVNULL).returncode == 0:
        changes_made.append("CPU server performance mode enabled")
        print(f"\r  {GREEN}✓{NC} CPU optimization applied")
    else:
        print(f"\r  {RED}✗{NC} Failed to optimize CPU settings")
    show_progress(current_step, total_steps)

    # 4. Network Stack Optimization
    print(f"\n{BOLD}4. Network Stack Optimization:{NC}")
    network_params = [
        "net.inet.tcp.delayed_ack=0",
        "net.inet.tcp.mssdflt=1440",
        "net.inet.tcp.win_scale_factor=8",
        "net.inet.tcp.sendspace=524288",
        "net.inet.tcp.recvspace=524288",
    ]
    for param in network_params:
        current_step += 1
        print(f"  {HOURGLASS} Setting {param}...", end="")
        if subprocess.run(["sudo", "sysctl", "-w", param], stderr=subprocess.DEVNULL).returncode == 0:
            changes_made.append(f"Network parameter {param} set")
            print(f"\r  {GREEN}✓{NC} {param} applied")
        else:
            print(f"\r  {RED}✗{NC} Failed to set {param}")
        show_progress(current_step, total_steps)

    # Summary
    print(f"\n{CYAN}Optimization Summary:{NC}")
    print(f"Total optimizations applied: {len(changes_made)}")
    for change in changes_made:
        print(f"{GREEN}✓{NC} {change}")

    success(f"System performance optimization completed with {len(changes_made)} improvements")
    return 0

# Progress bar function
def show_progress(percent: int, message: str = ''):
    width = 30
    completed = (width * percent) // 100
    remaining = width - completed
    print(f"\r{CYAN}[{'█' * completed}{'░' * remaining}]{NC} {percent:3}% {message}", end="")

# Progress tracking for optimizations (without dialog dependency)
def track_progress_no_dialog(step: int, total: int, message: str):
    percent = (step * 100) // total
    width = 50
    filled = (width * step) // total
    empty = width - filled
    print(f"\r  {GRAY}[{GREEN}{'█' * filled}{GRAY}{'░' * empty}] {BOLD}{percent:3}%{NC} {message}", end="")

# Graphics optimization
def optimize_graphics():
    log("Starting graphics optimization")
    print(f"\n{CYAN}Detailed Graphics Optimization Progress:{NC}")
    changes_made = []
    total_steps = 15
    current_step = 0

    # Create backup before making changes
    backup_graphics_settings()

    # 1. Window Server Optimizations
    print(f"\n{BOLD}1. Window Server Optimizations:{NC}")
    current_step += 1
    print(f"  {HOURGLASS} Optimizing drawing performance...", end="")
    if subprocess.run(["sudo", "defaults", "write", "/Library/Preferences/com.apple.windowserver", "UseOptimizedDrawing", "-bool", "true"], stderr=subprocess.DEVNULL).returncode == 0:
        subprocess.run(["defaults", "write", "com.apple.WindowServer", "UseOptimizedDrawing", "-bool", "true"], stderr=subprocess.DEVNULL)
        subprocess.run(["defaults", "write", "com.apple.WindowServer", "Accelerate", "-bool", "true"], stderr=subprocess.DEVNULL)
        subprocess.run(["defaults", "write", "com.apple.WindowServer", "EnableHiDPI", "-bool", "true"], stderr=subprocess.DEVNULL)
        changes_made.append("Drawing optimization enabled")
        print(f"\r  {GREEN}✓{NC} Drawing performance optimized")
    else:
        print(f"\r  {RED}✗{NC} Failed to optimize drawing performance")
    show_progress(current_step, total_steps)

    # 2. GPU Settings
    print(f"\n{BOLD}2. GPU Settings:{NC}")
    current_step += 1
    print(f"  {HOURGLASS} Optimizing GPU performance...", end="")
    if subprocess.run(["sudo", "defaults", "write", "com.apple.WindowServer", "MaximumGPUMemory", "-int", "4096"], stderr=subprocess.DEVNULL).returncode == 0:
        subprocess.run(["defaults", "write", "com.apple.WindowServer", "GPUPowerPolicy", "-string", "maximum"], stderr=subprocess.DEVNULL)
        subprocess.run(["defaults", "write", "com.apple.WindowServer", "DisableGPUProcessing", "-bool", "false"], stderr=subprocess.DEVNULL)
        changes_made.append("GPU performance maximized")
        print(f"\r  {GREEN}✓{NC} GPU settings optimized")
    else:
        print(f"\r  {RED}✗{NC} Failed to optimize GPU settings")
    show_progress(current_step, total_steps)

    # 3. Animation and Visual Effects
    print(f"\n{BOLD}3. Animation and Visual Effects:{NC}")
    current_step += 1
    print(f"  {HOURGLASS} Optimizing window animations...", end="")
    if subprocess.run(["sudo", "defaults", "write", "-g", "NSWindowResizeTime", "-float", "0.001"], stderr=subprocess.DEVNULL).returncode == 0:
        subprocess.run(["defaults", "write", "-g", "NSAutomaticWindowAnimationsEnabled", "-bool", "true"], stderr=subprocess.DEVNULL)
        subprocess.run(["defaults", "write", "-g", "NSWindowResizeTime", "-float", "0.001"], stderr=subprocess.DEVNULL)
        changes_made.append("Window animations optimized")
        print(f"\r  {GREEN}✓{NC} Window animations optimized")
    else:
        print(f"\r  {RED}✗{NC} Failed to optimize window animations")
    show_progress(current_step, total_steps)

    current_step += 1
    print(f"  {HOURGLASS} Adjusting dock animations...", end="")
    if subprocess.run(["sudo", "defaults", "write", "com.apple.dock", "autohide-time-modifier", "-float", "0.0"], stderr=subprocess.DEVNULL).returncode == 0 and \
       subprocess.run(["sudo", "defaults", "write", "com.apple.dock", "autohide-delay", "-float", "0.0"], stderr=subprocess.DEVNULL).returncode == 0:
        subprocess.run(["defaults", "write", "com.apple.dock", "autohide-time-modifier", "-float", "0.0"], stderr=subprocess.DEVNULL)
        subprocess.run(["defaults", "write", "com.apple.dock", "autohide-delay", "-float", "0.0"], stderr=subprocess.DEVNULL)
        changes_made.append("Dock animations optimized")
        print(f"\r  {GREEN}✓{NC} Dock animations adjusted")
    else:
        print(f"\r  {RED}✗{NC} Failed to adjust dock animations")
    show_progress(current_step, total_steps)

    # 4. Metal Performance
    print(f"\n{BOLD}4. Metal Performance:{NC}")
    current_step += 1
    print(f"  {HOURGLASS} Optimizing Metal performance...", end="")
    if subprocess.run(["sudo", "defaults", "write", "/Library/Preferences/com.apple.CoreDisplay", "useMetal", "-bool", "true"], stderr=subprocess.DEVNULL).returncode == 0 and \
       subprocess.run(["sudo", "defaults", "write", "/Library/Preferences/com.apple.CoreDisplay", "useIOP", "-bool", "true"], stderr=subprocess.DEVNULL).returncode == 0:
        subprocess.run(["defaults", "write", "NSGlobalDomain", "MetalForceHardwareRenderer", "-bool", "true"], stderr=subprocess.DEVNULL)
        subprocess.run(["defaults", "write", "NSGlobalDomain", "MetalLoadingPriority", "-string", "High"], stderr=subprocess.DEVNULL)
        changes_made.append("Metal performance optimized")
        print(f"\r  {GREEN}✓{NC} Metal performance optimized")
    else:
        print(f"\r  {RED}✗{NC} Failed to optimize Metal performance")
    show_progress(current_step, total_steps)

    # Force kill all UI processes to apply changes
    print(f"\n{HOURGLASS} Applying all changes (this may cause a brief screen flicker)...", end="")
    subprocess.run(["sudo", "killall", "Dock"], stderr=subprocess.DEVNULL)
    subprocess.run(["sudo", "killall", "Finder"], stderr=subprocess.DEVNULL)
    subprocess.run(["sudo", "killall", "SystemUIServer"], stderr=subprocess.DEVNULL)
    print(f"\r{GREEN}✓{NC} All changes applied")

    # Summary
    print(f"\n{CYAN}Optimization Summary:{NC}")
    print(f"Total optimizations applied: {len(changes_made)}")
    for change in changes_made:
        print(f"{GREEN}✓{NC} {change}")

    print(f"\n{YELLOW}Note: Some changes require logging out and back in to take full effect{NC}")
    print(f"{YELLOW}If changes are not visible, please log out and log back in{NC}")

    success(f"Graphics optimization completed with {len(changes_made)} improvements")
    return 0

# Helper function to backup graphics settings
def backup_graphics_settings():
    backup_file = os.path.join(BACKUP_DIR, f"graphics_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}")
    subprocess.run(["defaults", "export", "com.apple.WindowServer", f"{backup_file}.windowserver"], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["defaults", "export", "com.apple.dock", f"{backup_file}.dock"], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["defaults", "export", "com.apple.finder", f"{backup_file}.finder"], check=False, stderr=subprocess.DEVNULL)
    subprocess.run(["defaults", "export", "NSGlobalDomain", f"{backup_file}.global"], check=False, stderr=subprocess.DEVNULL)
    with open(os.path.join(BACKUP_DIR, "last_graphics_backup"), "w") as f:
        f.write(backup_file)
    log(f"Graphics settings backed up to {backup_file}")

# Helper function to restart UI services
def restart_ui_services(force: bool = False):
    subprocess.run(["killall", "Dock", "Finder", "SystemUIServer"], check=False, stderr=subprocess.DEVNULL)
    if force:
        time.sleep(2)
        subprocess.run(["sudo", "killall", "WindowServer"], check=False, stderr=subprocess.DEVNULL)

# Helper function to setup recovery
def setup_recovery():
    recovery_script = os.path.join(BASE_DIR, "recovery.sh")
    with open(recovery_script, "w") as f:
        f.write("""#!/bin/bash
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
""")
    os.chmod(recovery_script, 0o755)
    log(f"Recovery script created at {recovery_script}")

# Display optimization
def optimize_display():
    log("Starting display optimization")
    print("\n")
    print(f"{BOLD}{CYAN}Display Optimization{NC}")
    print(f"{DIM}Optimizing display settings for better performance...{NC}\n")
    os.makedirs(BACKUP_DIR, exist_ok=True)
    subprocess.run(["system_profiler", "SPDisplaysDataType"], stdout=open(f"{MEASUREMENTS_FILE}.before", "w"), check=False)
    total_steps = 5
    current_step = 0
    changes_made = []
    display_info = subprocess.getoutput("system_profiler SPDisplaysDataType")
    is_retina = "retina" in display_info.lower()
    is_scaled = "scaled" in display_info.lower()

    # Resolution optimization
    current_step += 1
    track_progress_no_dialog(current_step, total_steps, "Optimizing resolution settings")
    if is_retina:
        if subprocess.run(["sudo", "defaults", "write", "NSGlobalDomain", "AppleFontSmoothing", "-int", "0"], stderr=subprocess.DEVNULL).returncode == 0 and \
           subprocess.run(["sudo", "defaults", "write", "NSGlobalDomain", "CGFontRenderingFontSmoothingDisabled", "-bool", "true"], stderr=subprocess.DEVNULL).returncode == 0:
            changes_made.append("Optimized Retina display settings")
            print(f"\r  {GREEN}✓{NC} Optimized Retina settings for performance")
    else:
        if subprocess.run(["sudo", "defaults", "write", "NSGlobalDomain", "AppleFontSmoothing", "-int", "1"], stderr=subprocess.DEVNULL).returncode == 0:
            changes_made.append("Optimized standard display settings")
            print(f"\r  {GREEN}✓{NC} Optimized standard display settings")

    # Color profile optimization
    current_step += 1
    track_progress_no_dialog(current_step, total_steps, "Optimizing color settings")
    if subprocess.run(["sudo", "defaults", "write", "NSGlobalDomain", "AppleICUForce24HourTime", "-bool", "true"], stderr=subprocess.DEVNULL).returncode == 0 and \
       subprocess.run(["sudo", "defaults", "write", "NSGlobalDomain", "AppleDisplayScaleFactor", "-int", "1"], stderr=subprocess.DEVNULL).returncode == 0:
        changes_made.append("Optimized color settings")
        print(f"\r  {GREEN}✓{NC} Display color optimized")

    # Font rendering
    current_step += 1
    track_progress_no_dialog(current_step, total_steps, "Optimizing font rendering")
    if subprocess.run(["sudo", "defaults", "write", "NSGlobalDomain", "AppleFontSmoothing", "-int", "1"], stderr=subprocess.DEVNULL).returncode == 0 and \
       subprocess.run(["sudo", "defaults", "write", "-g", "CGFontRenderingFontSmoothingDisabled", "-bool", "NO"], stderr=subprocess.DEVNULL).returncode == 0:
        changes_made.append("Optimized font rendering")
        print(f"\r  {GREEN}✓{NC} Font rendering optimized")

    # Screen update optimization
    current_step += 1
    track_progress_no_dialog(current_step, total_steps, "Optimizing screen updates")
    if subprocess.run(["sudo", "defaults", "write", "com.apple.CrashReporter", "DialogType", "none"], stderr=subprocess.DEVNULL).returncode == 0 and \
       subprocess.run(["sudo", "defaults", "write", "com.apple.screencapture", "disable-shadow", "-bool", "true"], stderr=subprocess.DEVNULL).returncode == 0:
        changes_made.append("Optimized screen updates")
        print(f"\r  {GREEN}✓{NC} Screen updates optimized")

    # Apply changes
    current_step += 1
    track_progress_no_dialog(current_step, total_steps, "Applying display changes")
    subprocess.run(["killall", "SystemUIServer"], stderr=subprocess.DEVNULL)
    print(f"\r  {GREEN}✓{NC} Display changes applied")

    # Store final measurements
    subprocess.run(["system_profiler", "SPDisplaysDataType"], stdout=open(f"{MEASUREMENTS_FILE}.after", "w"), check=False)

    # Show optimization summary
    print(f"\n{CYAN}Optimization Summary:{NC}")
    print(f"Total optimizations applied: {len(changes_made)}")
    for change in changes_made:
        print(f"{GREEN}✓{NC} {change}")

    # Compare before/after display settings
    print(f"\n{CYAN}Display Settings Changes:{NC}")
    before_res = next((line.split(": ")[1] for line in open(f"{MEASUREMENTS_FILE}.before").readlines() if "Resolution:" in line), "N/A")
    after_res = next((line.split(": ")[1] for line in open(f"{MEASUREMENTS_FILE}.after").readlines() if "Resolution:" in line), "N/A")
    print(f"Resolution: {before_res} -> {after_res}")

    before_depth = next((line.split(": ")[1] for line in open(f"{MEASUREMENTS_FILE}.before").readlines() if "Depth:" in line), "N/A")
    after_depth = next((line.split(": ")[1] for line in open(f"{MEASUREMENTS_FILE}.after").readlines() if "Depth:" in line), "N/A")
    print(f"Color Depth: {before_depth} -> {after_depth}")

    print(f"\n{GREEN}Display optimization completed successfully{NC}")
    print(f"{DIM}Note: Some changes may require a logout/login to take full effect{NC}")
    time.sleep(1)
    return 0

# Storage optimization
def optimize_storage():
    log("Starting storage optimization")
    print(f"\n{CYAN}Storage Optimization Progress:{NC}")
    initial_space = subprocess.getoutput("df -h / | awk 'NR==2 {printf \"%s of %s\", $4, $2}'")
    print(f"{STATS} Initial Storage Available: {initial_space}")
    tmp_dir = subprocess.run(["mktemp", "-d"], capture_output=True, text=True, check=False).stdout.strip()
    total_steps = 5
    current_step = 0

    # 1. Clean User Cache
    current_step += 1
    print(f"\n{HOURGLASS} Cleaning user cache...", end="")
    with open(os.path.join(tmp_dir, "user_cache.log"), "w") as f:
        subprocess.run(["sudo", "rm", "-rf", os.path.expanduser("~/Library/Caches/*"), 
                       os.path.expanduser("~/Library/Application Support/*/Cache/*")], 
                       stdout=f, stderr=f, check=False)
    show_progress((current_step * 100) // total_steps, "User cache cleaned")

    # 2. Clean System Cache
    current_step += 1
    print(f"\n{HOURGLASS} Cleaning system cache...", end="")
    with open(os.path.join(tmp_dir, "system_cache.log"), "w") as f:
        subprocess.run(["sudo", "rm", "-rf", "/Library/Caches/*", "/System/Library/Caches/*"],
                      stdout=f, stderr=f, check=False)
    show_progress((current_step * 100) // total_steps, "System cache cleaned")

    # 3. Clean Docker files
    current_step += 1
    print(f"\n{HOURGLASS} Cleaning Docker files...", end="")
    with open(os.path.join(tmp_dir, "docker.log"), "w") as f:
        docker_paths = [
            "~/Library/Containers/com.docker.docker/Data/vms/*",
            "~/Library/Containers/com.docker.docker/Data/log/*", 
            "~/Library/Containers/com.docker.docker/Data/cache/*",
            "~/Library/Group Containers/group.com.docker/Data/cache/*",
            "~/Library/Containers/com.docker.docker/Data/tmp/*"
        ]
        for path in docker_paths:
            subprocess.run(["sudo", "rm", "-rf", os.path.expanduser(path)], 
                         stdout=f, stderr=f, check=False)
    show_progress((current_step * 100) // total_steps, "Docker files cleaned")

    # 4. Clean Development Cache
    current_step += 1
    print(f"\n{HOURGLASS} Cleaning development cache...", end="")
    with open(os.path.join(tmp_dir, "dev_cache.log"), "w") as f:
        subprocess.run(["sudo", "rm", "-rf", 
                       os.path.expanduser("~/Library/Developer/Xcode/DerivedData/*"),
                       os.path.expanduser("~/Library/Developer/Xcode/Archives/*")],
                       stdout=f, stderr=f, check=False)
    show_progress((current_step * 100) // total_steps, "Development cache cleaned")

    # 5. Clean System Logs
    current_step += 1
    print(f"\n{HOURGLASS} Cleaning system logs...", end="")
    with open(os.path.join(tmp_dir, "logs.log"), "w") as f:
        subprocess.run(["sudo", "rm", "-rf", "/private/var/log/*", 
                       os.path.expanduser("~/Library/Logs/*")],
                       stdout=f, stderr=f, check=False)
    show_progress((current_step * 100) // total_steps, "System logs cleaned")

    # Show final storage status
    final_space = subprocess.getoutput("df -h / | awk 'NR==2 {printf \"%s of %s\", $4, $2}'")
    print(f"\n\n{STATS} Final Storage Available: {final_space}")

    # Cleanup
    shutil.rmtree(tmp_dir, ignore_errors=True)

    success("Storage optimization completed")
    return 0

# Add missing constants
HOURGLASS = '⌛'
STATS = '📊'

# Add consistent styling classes
CARD_CLASSES = 'bg-white dark:bg-gray-800 shadow-xl rounded-xl hover:shadow-2xl transition-all duration-300'
HEADER_CARD_CLASSES = 'bg-gradient-to-br from-primary to-secondary text-white shadow-lg rounded-xl'
CONTENT_CLASSES = 'q-pa-lg gap-6'
GRID_CLASSES = 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'
BUTTON_BASE_CLASSES = 'rounded-lg transition-all duration-300 hover:shadow-lg'
ERROR_CLASSES = 'fixed bottom-4 right-4 z-50 flex flex-col gap-2'

class MacOptimizerUI:
    def __init__(self):
        self.current_task = None
        self.progress = 0
        self.notifications = []
        self.dark = True
        self.status = 'Ready'
        
        # Initialize progress indicators
        self.cpu_progress = None
        self.memory_progress = None
        self.disk_progress = None
        self.progress_bar = None
        self.progress_label = None
        self.status_label = None
        self.activity_list = None
        
        # Modern color scheme with better aesthetics
        ui.colors(
            primary='#1E40AF',    # Indigo
            secondary='#9333EA',  # Purple
            accent='#F97316',     # Orange
            positive='#10B981',   # Emerald
            negative='#EF4444',   # Red
            warning='#F59E0B',    # Amber
            info='#3B82F6',       # Blue
            dark='#1E293B'        # Slate dark
        )

        # Modern header with gradient
        with ui.header().classes('bg-gradient-to-br from-primary to-secondary text-white shadow-lg backdrop-blur-sm sticky top-0 z-50'):
            with ui.row().classes('w-full items-center justify-between q-px-md py-2'):
                with ui.row().classes('items-center gap-4'):
                    menu_btn = ui.button(on_click=lambda: ui.left_drawer.toggle())
                    menu_btn.props('flat round')
                    menu_btn.props('icon=menu')
                    menu_btn.classes('text-white hover:bg-white/10 transition-colors')
                    ui.label(f'Mac Optimizer v{VERSION}').classes('text-h6 font-bold')
                with ui.row().classes('items-center gap-4'):
                    notif_btn = ui.button(on_click=self.show_notifications)
                    notif_btn.props('flat round')
                    notif_btn.props('icon=notifications')
                    notif_btn.classes('text-white hover:bg-white/10 transition-colors')
                    notif_btn.tooltip('Notifications')
                    
                    dark_btn = ui.button(on_click=lambda: ui.dark_mode().toggle())
                    dark_btn.props('flat round')
                    dark_btn.props('icon=dark_mode')
                    dark_btn.classes('text-white hover:bg-white/10 transition-colors')
                    dark_btn.tooltip('Toggle Dark Mode')
                    
                    help_btn = ui.button(on_click=self.show_help)
                    help_btn.props('flat round')
                    help_btn.props('icon=help')
                    help_btn.classes('text-white hover:bg-white/10 transition-colors')
                    help_btn.tooltip('Help')
        
        # Modern navigation drawer
        with ui.left_drawer(fixed=True).classes('bg-white dark:bg-gray-800 shadow-xl'):
            with ui.column().classes('w-full h-full'):
                # User profile section
                with ui.card().classes(f'{HEADER_CARD_CLASSES} m-4'):
                    with ui.row().classes('items-center p-4 gap-4'):
                        ui.icon('computer').classes('text-3xl')
                        with ui.column().classes('gap-1'):
                            ui.label('Mac System').classes('text-lg font-bold')
                            ui.label(f'{MACOS_VERSION}').classes('text-sm opacity-90')
                
                # Navigation menu
                with ui.list().classes('w-full mt-4 rounded-lg overflow-hidden'):
                    menu_items = [
                        ('dashboard', 'Dashboard', 'dashboard'),
                        ('optimizations', 'Optimizations', 'tune'),
                        ('logs', 'System Logs', 'article'),
                        ('settings', 'Settings', 'settings'),
                    ]
                    for page, label, icon in menu_items:
                        with ui.item(on_click=lambda p=page: self.show_page(p)).classes(
                            'px-4 py-3 hover:bg-primary/10 dark:hover:bg-primary/20 cursor-pointer transition-colors'
                        ).props('active-class=text-primary'):
                            with ui.row().classes('items-center gap-4'):
                                ui.icon(icon).classes('text-xl')
                                ui.label(label).classes('font-medium')
        
        # Modern footer
        with ui.footer().classes('bg-gradient-to-br from-gray-900 to-gray-800 text-white shadow-up-lg'):
            with ui.row().classes('w-full items-center justify-between p-4'):
                ui.label('© 2024 Mac Optimizer').classes('text-sm text-gray-400')
                self.status_label = ui.label('Status: Ready').classes('text-sm text-gray-400')

        # Error display container
        self.error_container = ui.element('div').classes(ERROR_CLASSES)
        
        # Create main content area with proper padding and max width
        self.content = ui.element('div').classes('w-full max-w-7xl mx-auto p-6')
        
        # Create page containers
        self.pages = {
            'dashboard': ui.element('div').classes('w-full space-y-6'),
            'optimizations': ui.element('div').classes('w-full space-y-6'),
            'logs': ui.element('div').classes('w-full space-y-6'),
            'settings': ui.element('div').classes('w-full space-y-6')
        }
        
        # Setup pages
        with self.pages['dashboard']:
            self.setup_dashboard()
        with self.pages['optimizations']:
            self.setup_optimizations()
        with self.pages['logs']:
            self.setup_logs()
        with self.pages['settings']:
            self.setup_settings()
        
        # Hide all pages initially
        for page in self.pages.values():
            page.style('display: none')
        
        # Show dashboard by default
        self.show_page('dashboard')
        
        # Start log monitor
        self.log_monitor = ui.timer(1.0, self.update_logs)
        
        # Initialize notification center
        self.setup_notifications()
        
        # Initialize system monitor
        self.setup_system_monitor()

    def show_error(self, message: str):
        """Show error message in a nice card"""
        with self.error_container:
            error_card = ui.card().classes(
                'bg-red-100 dark:bg-red-900 text-red-800 dark:text-red-100 rounded-lg p-4 shadow-lg'
                'transform transition-all duration-300 hover:scale-105'
            )
            with error_card:
                with ui.row().classes('items-center gap-2'):
                    ui.icon('error').classes('text-xl')
                    ui.label(message).classes('font-medium')
            
            # Auto remove after 5 seconds
            ui.timer(5.0, lambda: error_card.delete(), once=True)

    async def update_system_status(self):
        """Update system status indicators with proper error handling"""
        try:
            # CPU Usage - handle floating point values
            cpu_output = subprocess.getoutput("ps -A -o %cpu | awk '{s+=$1} END {print s}'")
            try:
                cpu_usage = float(cpu_output)
                self.cpu_progress.value = min(int(cpu_usage), 100)
            except ValueError:
                self.cpu_progress.value = 0
            
            # Memory Usage - ensure proper integer conversion
            mem_info = subprocess.getoutput("vm_stat")
            try:
                pages_free = int(next(line.split()[2].replace('.', '') for line in mem_info.splitlines() if "Pages free" in line))
                pages_active = int(next(line.split()[2].replace('.', '') for line in mem_info.splitlines() if "Pages active" in line))
                pages_total = pages_free + pages_active
                mem_usage = int((pages_active / pages_total) * 100) if pages_total > 0 else 0
                self.memory_progress.value = mem_usage
            except (ValueError, StopIteration):
                self.memory_progress.value = 0
            
            # Disk Usage - handle percentage string properly
            try:
                disk_info = subprocess.getoutput("df -h / | awk 'NR==2 {print $5}'").replace('%', '')
                disk_usage = int(disk_info)
                self.disk_progress.value = disk_usage
            except ValueError:
                self.disk_progress.value = 0
            
        except Exception as e:
            # Use the new error display instead of notifications
            self.show_error(f"Error updating system status: {str(e)}")
            # Set default values
            self.cpu_progress.value = 0
            self.memory_progress.value = 0
            self.disk_progress.value = 0

    def setup_system_monitor(self):
        """Setup system monitor with improved styling"""
        with ui.card().classes(CARD_CLASSES):
            with ui.column().classes(CONTENT_CLASSES):
                ui.label('System Monitor').classes('text-2xl font-bold text-gray-900 dark:text-white')
                
                # Monitor grid
                with ui.grid(columns=3).classes('gap-6 mt-4'):
                    # CPU Monitor
                    with ui.card().classes('bg-gradient-to-br from-indigo-100 to-indigo-200 dark:from-indigo-900 dark:to-indigo-800 p-4 rounded-xl shadow-lg'):
                        with ui.row().classes('items-center gap-4'):
                            ui.icon('speed').classes('text-indigo-600 dark:text-indigo-400 text-2xl')
                            with ui.column().classes('flex-grow gap-2'):
                                ui.label('CPU Usage').classes('text-lg font-medium text-indigo-900 dark:text-indigo-100')
                                self.cpu_progress = ui.linear_progress(
                                    value=0, 
                                    show_value=True
                                ).props('rounded animated color=primary')
                    
                    # Memory Monitor
                    with ui.card().classes('bg-gradient-to-br from-green-100 to-green-200 dark:from-green-900 dark:to-green-800 p-4 rounded-xl shadow-lg'):
                        with ui.row().classes('items-center gap-4'):
                            ui.icon('memory').classes('text-green-600 dark:text-green-400 text-2xl')
                            with ui.column().classes('flex-grow gap-2'):
                                ui.label('Memory Usage').classes('text-lg font-medium text-green-900 dark:text-green-100')
                                self.memory_progress = ui.linear_progress(
                                    value=0,
                                    show_value=True
                                ).props('rounded animated color=positive')
                    
                    # Disk Monitor
                    with ui.card().classes('bg-gradient-to-br from-blue-100 to-blue-200 dark:from-blue-900 dark:to-blue-800 p-4 rounded-xl shadow-lg'):
                        with ui.row().classes('items-center gap-4'):
                            ui.icon('storage').classes('text-blue-600 dark:text-blue-400 text-2xl')
                            with ui.column().classes('flex-grow gap-2'):
                                ui.label('Disk Usage').classes('text-lg font-medium text-blue-900 dark:text-blue-100')
                                self.disk_progress = ui.linear_progress(
                                    value=0,
                                    show_value=True
                                ).props('rounded animated color=info')

    def setup_notifications(self):
        self.notification_center = ui.element('div').classes(
            'fixed top-4 right-4 z-50 flex flex-col gap-2 items-end'
        )

    def show_notification(self, message: str, type: str = 'info', timeout: int = 3000):
        gradients = {
            'info': 'from-blue-500 to-indigo-500',
            'success': 'from-green-500 to-teal-500',
            'warning': 'from-yellow-500 to-orange-500',
            'error': 'from-red-500 to-pink-500'
        }
        
        with self.notification_center:
            notification = ui.card().classes(
                f'bg-gradient-to-r {gradients[type]} text-white shadow-xl rounded-lg transform transition-all duration-300 hover:scale-105'
            )
            with notification:
                with ui.row().classes('items-center gap-2 p-3'):
                    ui.icon({
                        'info': 'info',
                        'success': 'check_circle',
                        'warning': 'warning',
                        'error': 'error'
                    }[type])
                    ui.label(message)
            
            # Added fade-in animation
            ui.timer(timeout / 1000, lambda: notification.delete(), once=True)

    def show_loading(self, message: str = 'Processing...'):
        with ui.element('div').classes(
            'fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center'
        ) as self.loading_overlay:
            with ui.card().classes('bg-white dark:bg-gray-800 p-6 rounded-xl shadow-2xl'):
                with ui.column().classes('items-center gap-4'):
                    ui.spinner('dots', size='xl', color='primary')
                    ui.label(message).classes('text-lg')

    def hide_loading(self):
        if hasattr(self, 'loading_overlay'):
            self.loading_overlay.delete()

    def show_confirmation(self, title: str, message: str, on_confirm, on_cancel=None):
        with ui.dialog() as dialog, ui.card().classes('p-4 rounded-xl'):
            ui.label(title).classes('text-h6 text-primary font-medium')
            ui.label(message).classes('text-body1 py-4')
            with ui.row().classes('justify-end gap-2'):
                cancel_btn = ui.button(
                    text='Cancel',
                    on_click=lambda: (dialog.close(), on_cancel() if on_cancel else None)
                )
                cancel_btn.props('flat color=grey-7')
                
                confirm_btn = ui.button(
                    text='Confirm',
                    on_click=lambda: (dialog.close(), on_confirm())
                )
                confirm_btn.props('rounded color=primary')

    def reset_settings(self, dialog):
        # Implementation for settings reset
        dialog.close()
        ui.notify('Settings reset to default values', type='info')

    def backup_current_settings(self):
        try:
            backup_graphics_settings()
            ui.notify('Settings backed up successfully', type='positive')
        except Exception as e:
            ui.notify(f'Backup failed: {str(e)}', type='negative')

    async def run_verification(self):
        self.progress_label.text = 'Verifying system state...'
        result = verify_system_state()
        if result:
            ui.notify('System verification passed', type='positive')
        else:
            ui.notify('System verification failed', type='negative')

    def optimize_system_performance(self):
        """Optimize system performance"""
        log("Starting system performance optimization")
        changes_made = []
        
        try:
            # Kernel Parameter Optimization
            sysctl_params = [
                "kern.maxvnodes=750000",
                "kern.maxproc=4096",
                "kern.maxfiles=524288",
                "kern.ipc.somaxconn=4096",
            ]
            for param in sysctl_params:
                if subprocess.run(["sudo", "sysctl", "-w", param], stderr=subprocess.DEVNULL).returncode == 0:
                    changes_made.append(f"Kernel parameter {param} set")

            # Performance Mode Settings
            if subprocess.run(["sudo", "pmset", "-a", "highperf", "1"], stderr=subprocess.DEVNULL).returncode == 0:
                changes_made.append("High performance mode enabled")

            # CPU and Memory Optimization
            if subprocess.run(["sudo", "nvram", "boot-args=serverperfmode=1"], stderr=subprocess.DEVNULL).returncode == 0:
                changes_made.append("CPU server performance mode enabled")

            success(f"System performance optimization completed with {len(changes_made)} improvements")
            return 0
        except Exception as e:
            error(f"Error during system optimization: {str(e)}")
            return 1

    def optimize_graphics(self):
        """Optimize graphics settings"""
        log("Starting graphics optimization")
        changes_made = []
        
        try:
            # Window Server Optimizations
            if subprocess.run(["defaults", "write", "com.apple.WindowServer", "Accelerate", "-bool", "true"], stderr=subprocess.DEVNULL).returncode == 0:
                changes_made.append("Graphics acceleration enabled")

            # GPU Settings
            if subprocess.run(["defaults", "write", "com.apple.WindowServer", "GPUPowerPolicy", "-string", "maximum"], stderr=subprocess.DEVNULL).returncode == 0:
                changes_made.append("GPU power policy maximized")

            success(f"Graphics optimization completed with {len(changes_made)} improvements")
            return 0
        except Exception as e:
            error(f"Error during graphics optimization: {str(e)}")
            return 1

    def optimize_display(self):
        """Optimize display settings"""
        log("Starting display optimization")
        changes_made = []
        
        try:
            # Font rendering optimization
            if subprocess.run(["defaults", "write", "NSGlobalDomain", "AppleFontSmoothing", "-int", "1"], stderr=subprocess.DEVNULL).returncode == 0:
                changes_made.append("Font smoothing optimized")

            # Screen update optimization
            if subprocess.run(["defaults", "write", "com.apple.screencapture", "disable-shadow", "-bool", "true"], stderr=subprocess.DEVNULL).returncode == 0:
                changes_made.append("Screen capture optimized")

            success(f"Display optimization completed with {len(changes_made)} improvements")
            return 0
        except Exception as e:
            error(f"Error during display optimization: {str(e)}")
            return 1

    def optimize_storage(self):
        """Optimize storage usage"""
        log("Starting storage optimization")
        changes_made = []
        
        try:
            # Clean User Cache
            user_cache = os.path.expanduser("~/Library/Caches")
            if os.path.exists(user_cache):
                subprocess.run(["rm", "-rf", user_cache + "/*"], stderr=subprocess.DEVNULL)
                changes_made.append("User cache cleaned")

            # Clean System Logs
            if subprocess.run(["sudo", "rm", "-rf", "/private/var/log/*"], stderr=subprocess.DEVNULL).returncode == 0:
                changes_made.append("System logs cleaned")

            success(f"Storage optimization completed with {len(changes_made)} improvements")
            return 0
        except Exception as e:
            error(f"Error during storage optimization: {str(e)}")
            return 1

    def clear_logs(self):
        """Clear the log area and optionally the log file"""
        self.log_area.value = ''
        if os.path.exists(LOG_FILE):
            try:
                with open(LOG_FILE, 'w') as f:
                    f.write('')
                ui.notify('Logs cleared successfully', type='positive')
            except Exception as e:
                ui.notify(f'Error clearing logs: {str(e)}', type='negative')

    def filter_logs(self):
        """Filter logs based on selected level"""
        if not os.path.exists(LOG_FILE):
            return
        
        try:
            with open(LOG_FILE, 'r') as f:
                logs = f.readlines()
            
            filtered_logs = []
            level = self.log_level.value
            
            for log in logs:
                if level == 'All' or f'[{level}]' in log:
                    filtered_logs.append(log)
            
            self.log_area.value = ''.join(filtered_logs)
        except Exception as e:
            ui.notify(f'Error filtering logs: {str(e)}', type='negative')

    def set_status(self, status: str):
        """Update status text"""
        self.status = status
        self.status_label.text = f'Status: {status}'

    async def update_logs(self):
        """Update logs in real-time"""
        if os.path.exists(LOG_FILE):
            try:
                with open(LOG_FILE, 'r') as f:
                    new_logs = f.read()
                if new_logs != self.log_area.value:
                    self.log_area.value = new_logs
            except Exception as e:
                ui.notify(f'Error updating logs: {str(e)}', type='negative')

    def update_activity(self):
        """Update recent activity list"""
        if hasattr(self, 'activity_list'):
            for child in self.activity_list.default_slot.children:
                self.activity_list.remove(child)
            
            for activity in self.notifications[-5:]:
                with self.activity_list:
                    with ui.row().classes('items-center q-gutter-sm'):
                        ui.icon(activity['icon']).classes(activity['color'])
                        ui.label(activity['text']).classes('text-caption')

    def add_activity(self, text: str, icon: str = 'info', color: str = 'text-primary'):
        """Add new activity to the list"""
        self.notifications.append({
            'icon': icon,
            'color': color,
            'text': text,
            'time': datetime.datetime.now()
        })
        self.update_activity()

    async def run_with_progress(self, func):
        try:
            result = await asyncio.to_thread(func)
            return result
        except Exception as e:
            error_msg = f"Error during optimization: {str(e)}\n{traceback.format_exc()}"
            self.log_error(error_msg)
            raise
            
    def log_error(self, message: str):
        timestamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        with open(LOG_FILE, 'a') as f:
            f.write(f"[{timestamp}] ERROR: {message}\n")
        self.notifications.append({
            'icon': 'error',
            'color': 'text-red-500',
            'text': message
        })

    def show_notifications(self):
        with ui.dialog() as dialog, ui.card():
            ui.label('Notifications').classes('text-xl font-bold mb-4')
            with ui.element('div').classes('overflow-y-auto max-h-64'):
                for msg in self.get_recent_notifications():
                    with ui.row().classes('items-center gap-2 p-2 hover:bg-blue-50 rounded'):
                        ui.icon(msg['icon']).classes(msg['color'])
                        ui.label(msg['text']).classes('text-sm')
            close_btn = ui.button(
                text='Close',
                on_click=dialog.close
            )
            close_btn.classes('mt-4')

    def get_free_memory(self) -> float:
        mem_info = subprocess.getoutput("vm_stat | grep 'Pages free:'").split()[2]
        return int(mem_info.strip(".")) * 4096 / 1024 / 1024

    def update_progress(self, value: float, message: str = ''):
        self.progress_bar.value = value
        self.progress_percentage.text = f'{int(value * 100)}%'
        if message:
            self.status_label.text = message

    def get_recent_notifications(self) -> list:
        # Implement notification storage and retrieval
        return [
            {'icon': 'check_circle', 'color': 'text-green-500', 'text': 'Last optimization completed successfully'},
            {'icon': 'backup', 'color': 'text-blue-500', 'text': 'Settings backed up'},
            {'icon': 'warning', 'color': 'text-yellow-500', 'text': 'System verification recommended'}
        ]

    async def run_optimization(self, optimization_func):
        if self.current_task:
            self.show_notification('An optimization is already running', type='warning')
            return

        try:
            self.show_loading('Running optimization...')
            self.progress_label.text = 'Running optimization...'
            self.progress_bar.value = 0
            self.progress_percentage.text = '0%'
            
            self.current_task = asyncio.create_task(self.run_with_progress(optimization_func))
            result = await self.current_task
            
            if result == 0:
                self.show_notification('Optimization completed successfully', type='success')
                self.add_activity('Optimization completed', icon='check_circle', color='text-green-500')
            else:
                self.show_notification('Optimization completed with warnings', type='warning')
                self.add_activity('Optimization completed with warnings', icon='warning', color='text-yellow-500')
            
            self.progress_label.text = 'Optimization Complete'
            self.progress_bar.value = 1
            self.progress_percentage.text = '100%'
            
        except Exception as e:
            error_msg = str(e)
            self.show_notification(f'Error: {error_msg}', type='error')
            self.progress_label.text = 'Error'
            self.add_activity(f'Error: {error_msg}', icon='error', color='text-red-500')
        finally:
            self.current_task = None
            self.hide_loading()

    def show_help(self):
        with ui.dialog() as dialog, ui.card():
            ui.label('Mac Optimizer Help').classes('text-xl font-bold')
            ui.label('This tool helps optimize your Mac\'s performance through various optimizations.')
            ui.label('Each optimization category focuses on different aspects of your system:')
            with ui.column().classes('mt-2 space-y-2'):
                ui.label('• System Performance: Kernel and CPU optimizations')
                ui.label('• Graphics: GPU and visual performance')
                ui.label('• Display: Screen and rendering settings')
                ui.label('• Storage: Cache and temporary file cleanup')
            close_btn = ui.button(
                text='Close',
                on_click=dialog.close
            )
            close_btn.classes('mt-4')

    def refresh_logs(self):
        """Refresh the log display"""
        try:
            if os.path.exists(LOG_FILE):
                with open(LOG_FILE, 'r') as f:
                    self.log_area.value = f.read()
                ui.notify('Logs refreshed', type='positive')
            else:
                self.log_area.value = 'No logs available'
        except Exception as e:
            ui.notify(f'Error refreshing logs: {str(e)}', type='negative')

    def confirm_reset(self):
        with ui.dialog() as dialog, ui.card().classes('p-4 rounded-xl'):
            ui.label('Confirm Reset').classes('text-lg font-bold')
            ui.label('Are you sure you want to reset all settings to default?')
            with ui.row().classes('justify-end gap-2'):
                cancel_btn = ui.button(
                    text='Cancel',
                    on_click=lambda: (dialog.close(), on_cancel() if on_cancel else None)
                )
                cancel_btn.props('flat color=grey-7')
                
                confirm_btn = ui.button(
                    text='Confirm',
                    on_click=lambda: (dialog.close(), on_confirm())
                )
                confirm_btn.props('rounded color=primary')

# Modified progress tracking functions to update UI
def show_progress(percent: int, message: str = ''):
    if hasattr(ui, 'current'):
        ui.current.optimizer.update_progress(percent / 100, message)

def track_progress_no_dialog(step: int, total: int, message: str):
    if hasattr(ui, 'current'):
        ui.current.optimizer.update_progress(step / total, message)

# Main entry point
def main():
    try:
        # Ensure required directories exist
        os.makedirs(BASE_DIR, exist_ok=True)
        os.makedirs(BACKUP_DIR, exist_ok=True)
        os.makedirs(PROFILES_DIR, exist_ok=True)
        
        app = MacOptimizerUI()
        
        ui.run(
            title='Mac Optimizer',
            port=8080,
            dark=True,
            reload=False,
            show=True,
            storage_secret='mac_optimizer',
            favicon='🚀'
        )
    except Exception as e:
        print(f"Error starting application: {str(e)}")
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()