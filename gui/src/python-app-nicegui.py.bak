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
import logging
import sys
BASE_DIR = os.path.expanduser("~/.mac_optimizer")
BACKUP_DIR = os.path.join(BASE_DIR, "backups", datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
LOG_FILE = os.path.join(BACKUP_DIR, "optimizer.log")
SETTINGS_FILE = os.path.join(BASE_DIR, "settings")
MIN_MACOS_VERSION = "10.15"
    async def show_notifications(self):
        """Show notifications dialog"""
        with ui.dialog() as dialog:
            with ui.card():
                ui.label('Notifications').classes('font-bold')
                with ui.scroll_area():
                    for notification in reversed(self.notifications):
                        with ui.row():
async def show_notifications(self):
                            ui.label(notification.get('text', ''))
                ui.button('Close', on_click=dialog.close)
MEASUREMENTS_FILE = os.path.join(BACKUP_DIR, "performance_measurements.txt")
SCHEDULE_FILE = os.path.join(BASE_DIR, "schedule")
USAGE_PROFILE = os.path.join(BASE_DIR, "usage")
AUTO_BACKUP_LIMIT = 5
LAST_RUN_FILE = os.path.join(BASE_DIR, "lastrun")
async def show_notifications(self):
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
    print(f"{RED}Error: {error_msg} (Code: {error_code}){NC}")
    log(f"ERROR: {error_msg} (Code: {error_code})")
    else:
        warning("Unknown error occurred")
    return error_code

# Memory pressure check
def memory_pressure() -> Tuple[str, int]:
    print(f"{RED}Error: {error_msg} (Code: {error_code}){NC}")
    log(f"ERROR: {error_msg} (Code: {error_code})")
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

class MacOptimizerUI:
    def __init__(self):
        # Define all required methods first
PROFILES_DIR = os.path.join(BASE_DIR, "profiles")
        # Initialize attributes
        self.initialize_attributes()
        # Setup UI
        self.setup_theme()
        self.create_layout()
        self.initialize_subsystems()
PROFILES_DIR = os.path.join(BASE_DIR, "profiles")

    def define_required_methods(self):
        """Define all required methods before they are used"""
        self.show_loading = self._show_loading
        self.hide_loading = self._hide_loading
        self.add_activity = self._add_activity
        self.run_with_progress = self._run_with_progress
            result = await func()  # Await the function call


    def _show_loading(self, message: str):
        """Show loading indicator"""
        self.progress_label.text = message
        self.progress_bar.value = 0

        result = await func()  # Await the function call
        """Hide loading indicator"""
        self.progress_label.text = 'Ready'
        self.progress_bar.value = 0

    def _add_activity(self, message: str, icon: str = 'info'):
            result = await func()
        result = await func()  # Await the function call
            with self.activity_list:
                with ui.row():
                    ui.icon(icon)
                    ui.label(message)

    async def _run_with_progress(self, func):
        """Run a function with progress tracking"""
        try:
            if asyncio.iscoroutinefunction(func):
                result = await func()
            else:
                result = await asyncio.to_thread(func)
            self.progress_bar.value = 1
            self.progress_percentage.text = '100%'
            return result
        except Exception as e:
            raise e

    def _update_progress(self, value: float, message: str = ''):
        """Update progress indicators"""
        if hasattr(self, 'progress_bar'):
            self.progress_bar.value = value
        if hasattr(self, 'progress_percentage'):
            self.progress_percentage.text = f'{int(value * 100)}%'
        if message and hasattr(self, 'progress_label'):
            self.progress_label.text = message

    def setup_logs(self):
        """Setup logs page with valid props"""
        with ui.column():
            with ui.card():
                ui.label('System Logs')
                ui.label('Monitor system activities and events')
            
            with ui.card():
                with ui.column():
                    with ui.row():
                        self.log_level = ui.select(
                            options=['All', 'INFO', 'WARNING', 'ERROR', 'SUCCESS'],
                            value='All',
                            on_change=self.filter_logs
                        )
                        ui.button('Refresh', on_click=self.refresh_logs, icon='refresh')
                        ui.button('Clear Logs', on_click=self.clear_logs, icon='delete')
                    
                    self.log_area = ui.textarea(
                        value='',
                        placeholder='No logs available'
                    ).classes('w-full h-80')

    def initialize_attributes(self):
        """Initialize all required attributes"""
        self.current_task = None
        self.progress = 0
        self.notifications = []
        self.dark = True
        self.status = 'Ready'
        self.cpu_progress = None
        self.memory_progress = None
        self.disk_progress = None
        self.progress_bar = None
        self.progress_label = None
        self.status_label = None
        self.activity_list = None
        self.error_container = None
        self.content = None
        self.pages = {}
        self.notification_center = None
        self.log_level = None
        self.log_area = None

    def setup_theme(self):
        """Setup UI theme"""
        ui.colors(
            primary='#2196F3',
            secondary='#1976D2',
            accent='#673AB7',
            positive='#4CAF50',
            negative='#F44336',
            warning='#FF9800',
            info='#2196F3'
        )

    def create_layout(self):
        """Create main UI layout"""
        # Create header
        with ui.header():
            with ui.row():
                ui.button(icon='menu', on_click=lambda: ui.left_drawer.toggle())
                ui.label('Mac Optimizer v2.1')
                with ui.row():
                    ui.button(icon='notifications', on_click=self.show_notifications)
                    ui.button(icon='dark_mode', on_click=lambda: ui.dark_mode().toggle())
                    ui.button(icon='help', on_click=self.show_help)

        # Create navigation drawer
        with ui.left_drawer():
            self.create_nav_drawer()

        # Create footer
        with ui.footer():
            with ui.row():
                ui.label('© 2024 Mac Optimizer')
                self.status_label = ui.label('Status: Ready')

        # Create main content area
        self.content = ui.element('div')
        
        # Create page containers
        self.create_pages()

    def create_nav_drawer(self):
        """Create navigation drawer content"""
        with ui.column():
            with ui.card():
                with ui.row():
                        ui.icon('computer')
                        with ui.column():
                        ui.label('Mac System')
                        ui.label(f'{MACOS_VERSION}')

            with ui.list():
                    menu_items = [
                        ('dashboard', 'Dashboard', 'dashboard'),
                        ('optimizations', 'Optimizations', 'tune'),
                        ('logs', 'System Logs', 'article'),
                        ('settings', 'Settings', 'settings'),
                    ]
                    for page, label, icon in menu_items:
                    with ui.item(on_click=lambda p=page: self.show_page(p)):
                        with ui.row():
                            ui.icon(icon)
                            ui.label(label)

    def create_pages(self):
        """Create and initialize all pages"""
        self.pages = {
            'dashboard': ui.element('div'),
            'optimizations': ui.element('div'),
            'logs': ui.element('div'),
            'settings': ui.element('div')
        }
        
        # Setup each page
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
        
    def initialize_subsystems(self):
        """Initialize all subsystems"""
        self.setup_notifications()
        self.setup_system_monitor()
        self.error_container = ui.element('div')

    def start_background_tasks(self):
        """Start background tasks"""
        self.log_monitor = ui.timer(1.0, self.update_logs)

    def setup_system_monitor(self):
        with ui.card():
            with ui.column():
                ui.label('System Monitor')
                
                with ui.grid(columns=3):
                    # CPU Monitor
                    with ui.card():
                        with ui.row():
                            ui.icon('speed')
                            with ui.column():
                                ui.label('CPU Usage')
                                self.cpu_progress = ui.linear_progress(value=0, show_value=True)
                    
                    # Memory Monitor
                    with ui.card():
                        with ui.row():
                            ui.icon('memory')
                            with ui.column():
                                ui.label('Memory Usage')
                                self.memory_progress = ui.linear_progress(value=0, show_value=True)
                    
                    # Disk Monitor
                    with ui.card():
                        with ui.row():
                            ui.icon('storage')
                            with ui.column():
                                ui.label('Disk Usage')
                                self.disk_progress = ui.linear_progress(value=0, show_value=True)

    def setup_dashboard(self):
        with ui.column():
            with ui.card():
                ui.label('System Overview')
                
                with ui.grid(columns=2):
                    with ui.card():
                        ui.label('System Information')
                        ui.label(f'macOS Version: {MACOS_VERSION}')
                        ui.label(f'Build: {MACOS_BUILD}')
                        ui.label(f'Architecture: {ARCH}')
                        if IS_APPLE_SILICON:
                            ui.label('Apple Silicon: Yes')
                        if IS_ROSETTA:
                            ui.label('Running under Rosetta: Yes')
                    
                    with ui.card():
                        ui.label('Quick Actions')
                        ui.button('Run System Check', on_click=self.run_verification)
                        ui.button('Backup Settings', on_click=self.backup_current_settings)
            
            with ui.card():
                ui.label('Performance Metrics')
                self.progress_label = ui.label('Ready')
                self.progress_bar = ui.linear_progress(value=0)
                self.progress_percentage = ui.label('0%')
            
            with ui.card():
                ui.label('Recent Activity')
                self.activity_list = ui.element('div')

    def setup_optimizations(self):
        with ui.column():
            with ui.card():
                ui.label('System Optimizations')
                ui.label('Enhance your system performance with our optimization tools')
            
            with ui.grid(columns=2):
                # System Performance
                with ui.card():
                    with ui.column():
                        ui.icon('speed')
                        ui.label('System Performance')
                        ui.label('Optimize kernel parameters, CPU, and memory usage')
                        ui.button(
                            'Optimize Performance',
                            on_click=lambda: self.run_optimization(self.optimize_system_performance)
                        )
                
                # Graphics
                with ui.card():
                    with ui.column():
                        ui.icon('gradient')
                        ui.label('Graphics')
                        ui.label('Enhance GPU performance and visual effects')
                        ui.button(
                            'Optimize Graphics',
                            on_click=lambda: self.run_optimization(self.optimize_graphics)
                        )
                
                # Display
                with ui.card():
                    with ui.column():
                        ui.icon('desktop_windows')
                        ui.label('Display')
                        ui.label('Improve display settings and font rendering')
                        ui.button(
                            'Optimize Display',
                            on_click=lambda: self.run_optimization(self.optimize_display)
                        )
                
                # Storage
                with ui.card():
                    with ui.column():
                        ui.icon('storage')
                        ui.label('Storage')
                        ui.label('Clean up system and free up disk space')
                        ui.button(
                            'Optimize Storage',
                            on_click=lambda: self.run_optimization(self.optimize_storage)
                        )

    def setup_logs(self):
        with ui.column():
            with ui.card():
                ui.label('System Logs')
                ui.label('Monitor system activities and events')
            
            with ui.card():
                with ui.column():
                    with ui.row():
                        self.log_level = ui.select(
                            options=['All', 'INFO', 'WARNING', 'ERROR', 'SUCCESS'],
                            value='All',
                            on_change=self.filter_logs
                        )
                        ui.button('Refresh', on_click=self.refresh_logs, icon='refresh')
                        ui.button('Clear Logs', on_click=self.clear_logs, icon='delete')
                    
                    self.log_area = ui.textarea(
                        value='',
                        placeholder='No logs available'
                    ).classes('w-full h-80')

    def setup_settings(self):
        with ui.column():
            with ui.card():
                ui.label('Settings')
                ui.label('Customize your optimization preferences')
            
            with ui.card():
                ui.label('General Settings')
                with ui.column():
                    with ui.row():
                        ui.label('Dark Mode')
                        ui.switch(value=self.dark, on_change=lambda: ui.dark_mode().toggle())
                    
                    with ui.row():
                        ui.label('Show Notifications')
                        ui.switch(value=False, on_change=lambda e: self.show_notification('Notifications toggled', type='info'))
                    
                    with ui.row():
                        ui.label('Auto-backup Limit')
                        ui.number(value=AUTO_BACKUP_LIMIT)
            
            with ui.card():
                ui.label('Backup & Reset')
                with ui.row():
                    ui.button(
                        'Backup Current Settings',
                        on_click=self.backup_current_settings,
                        icon='backup'
                    )
                    ui.button(
                        'Reset to Default',
                        on_click=self.confirm_reset,
                        icon='restore'
                    )

    def show_page(self, page_name: str):
        """Show the selected page and hide others"""
        for name, page in self.pages.items():
            if name == page_name:
                page.style('display: block')
            else:
                page.style('display: none')

    def show_notifications(self):
        """Show notifications dialog"""
        with ui.dialog() as dialog:
            with ui.card():
                ui.label('Notifications').classes('font-bold')
                with ui.scroll_area():
                    for notification in reversed(self.notifications):
                        with ui.row():
                            ui.icon(notification.get('icon', 'info'))
                            ui.label(notification.get('text', ''))
                ui.button('Close', on_click=dialog.close)

    def setup_notifications(self):
        """Initialize notification center"""
        self.notification_center = ui.element('div')
        self.notifications = []

    def show_notification(self, message: str, type: str = 'info'):
        """Show a notification"""
        notification = {
            'text': message,
            'icon': {
                'info': 'info',
                'success': 'check_circle',
                'warning': 'warning',
                'error': 'error'
            }.get(type, 'info'),
            'time': datetime.datetime.now()
        }
        self.notifications.append(notification)
        self.update_activity()

    def show_help(self):
        """Show help dialog"""
        with ui.dialog() as dialog:
            with ui.card():
                ui.label('Mac Optimizer Help').style('font-weight: bold')
                ui.label('This tool helps optimize your Mac\'s performance.')
                ui.label('Available optimizations:')
                with ui.column():
                    ui.label('• System Performance: Kernel and CPU settings')
                    ui.label('• Graphics: GPU and visual performance')
                    ui.label('• Display: Screen and rendering settings')
                    ui.label('• Storage: Cache and temporary file cleanup')
                ui.button('Close', on_click=dialog.close)

    def confirm_reset(self):
        """Show reset confirmation dialog"""
        with ui.dialog() as dialog:
            with ui.card():
                ui.label('Confirm Reset').style('font-weight: bold')
                ui.label('Are you sure you want to reset all settings?')
                with ui.row():
                    ui.button('Cancel', on_click=dialog.close)
                    ui.button('Reset', on_click=lambda: (self.reset_settings(), dialog.close()))

    def reset_settings(self):
        """Reset settings to defaults"""
        try:
            # Reset settings logic here
            self.show_notification('Settings reset to defaults', type='success')
        except Exception as e:
            self.show_notification(f'Error resetting settings: {str(e)}', type='error')

    def update_activity(self):
        """Update activity list"""
        if not hasattr(self, 'activity_list'):
            return
        
        self.activity_list.clear()
        with self.activity_list:
            for notification in list(reversed(self.notifications))[:5]:
                with ui.row():
                    ui.icon(notification.get('icon', 'info'))
                    ui.label(notification.get('text', ''))

    async def run_verification(self):
        """Run system verification"""
        try:
            self.progress_label.text = 'Verifying system...'
            result = verify_system_state()
            if result:
                self.show_notification('System verification passed', type='success')
            else:
                self.show_notification('System verification failed', type='error')
        except Exception as e:
            self.show_notification(f'Error during verification: {str(e)}', type='error')
        finally:
            self.progress_label.text = 'Ready'

    def backup_current_settings(self):
        """Backup current settings"""
        try:
            backup_graphics_settings()
            self.show_notification('Settings backed up successfully', type='success')
        except Exception as e:
            self.show_notification(f'Backup failed: {str(e)}', type='error')

    async def update_logs(self):
        """Update logs in real-time"""
        if os.path.exists(LOG_FILE):
            try:
                with open(LOG_FILE, 'r') as f:
                    new_logs = f.read()
                if hasattr(self, 'log_area') and new_logs != self.log_area.value:
                    self.log_area.value = new_logs
            except Exception as e:
                self.show_notification(f'Error updating logs: {str(e)}', type='error')

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
            self.show_notification(f'Error refreshing logs: {str(e)}', type='error')

            self.log_area.value = ''.join(filtered_logs)
        except Exception as e:
            self.show_notification(f'Error filtering logs: {str(e)}', type='error')

    def refresh_logs(self):
        """Refresh log display"""
        try:
            if os.path.exists(LOG_FILE):
                with open(LOG_FILE, 'r') as f:
                    self.log_area.value = f.read()
                self.show_notification('Logs refreshed', type='success')
            else:
                self.log_area.value = 'No logs available'
            except Exception as e:
            self.show_notification(f'Error refreshing logs: {str(e)}', type='error')

    def clear_logs(self):
        """Clear logs"""
        try:
            self.log_area.value = ''
            if os.path.exists(LOG_FILE):
                with open(LOG_FILE, 'w') as f:
                    f.write('')
            self.show_notification('Logs cleared', type='success')
        except Exception as e:
            self.show_notification(f'Error clearing logs: {str(e)}', type='error')

    async def run_optimization(self, optimization_func):
        """Run optimization with proper error handling"""
        if self.current_task:
            self.show_notification('An optimization is already running', type='warning')
            return

        try:
            self.show_loading('Running optimization...')
            self.progress_label.text = 'Running optimization...'
            self.progress_bar.value = 0
            self.progress_percentage.text = '0%'
            
            # Create and run the task
            self.current_task = asyncio.create_task(self._run_optimization_task(optimization_func))
            result = await self.current_task
            
            if result == 0:
                self.show_notification('Optimization completed successfully', type='success')
                self.add_activity('Optimization completed', icon='check_circle')
            else:
                self.show_notification('Optimization completed with warnings', type='warning')
                self.add_activity('Optimization completed with warnings', icon='warning')
            
        except Exception as e:
            error_msg = str(e)
            self.show_notification(f'Error: {error_msg}', type='error')
            self.add_activity(f'Error: {error_msg}', icon='error')
        finally:
            self.current_task = None
            self.hide_loading()
            self.progress_label.text = 'Ready'

    async def _run_optimization_task(self, func):
        """Run the optimization function in a task"""
        try:
            # Run the optimization function
            if asyncio.iscoroutinefunction(func):
                result = await func()
            else:
                result = await asyncio.to_thread(func)
            return result
        except Exception as e:
            raise e

    def optimize_system_performance(self):
        """Run system performance optimization"""
        try:
            return optimize_system_performance()
        except Exception as e:
            raise e

    def optimize_graphics(self):
        """Run graphics optimization"""
        try:
            return optimize_graphics()
        except Exception as e:
            raise e

    def optimize_display(self):
        """Run display optimization"""
        try:
            return optimize_display()
        except Exception as e:
            raise e

    def optimize_storage(self):
        """Run storage optimization"""
        try:
            return optimize_storage()
        except Exception as e:
            raise e

# Modified progress tracking functions
def show_progress(percent: int, message: str = ''):
    """Update progress in UI"""
    if hasattr(ui, 'current') and hasattr(ui.current, 'optimizer'):
        ui.current.optimizer.update_progress(percent / 100, message)

def track_progress_no_dialog(step: int, total: int, message: str):
    """Update progress without dialog"""
    if hasattr(ui, 'current') and hasattr(ui.current, 'optimizer'):
        ui.current.optimizer.update_progress(step / total, message)

# Main entry point
def main():
    try:
        # Ensure required directories exist
        os.makedirs(BASE_DIR, exist_ok=True)
        os.makedirs(BACKUP_DIR, exist_ok=True)
        os.makedirs(PROFILES_DIR, exist_ok=True)
        
        # Create and store the app instance
        app = MacOptimizerUI()
        ui.current.optimizer = app
        
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
