#!/usr/bin/env python3
"""macOS Optimizer GUI — NiceGUI frontend."""

from __future__ import annotations

import asyncio
import os
import platform
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Callable, List, Optional

# Allow importing shared config from repo root / config package
ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from config.settings import (  # noqa: E402
    BASE_DIR,
    GUI_HOST,
    GUI_PORT,
    GUI_TITLE,
    LOG_DIR,
    OPTIMIZATION_CATEGORIES,
    VERSION,
)

try:
    import psutil
except ImportError:  # pragma: no cover - runtime dependency
    psutil = None  # type: ignore

from nicegui import app, ui  # noqa: E402


def is_macos() -> bool:
    return platform.system() == "Darwin"


def run_cmd(args: List[str], check: bool = False) -> subprocess.CompletedProcess:
    return subprocess.run(args, capture_output=True, text=True, check=check)


def read_macos_version() -> str:
    if not is_macos():
        return platform.platform()
    try:
        return run_cmd(["sw_vers", "-productVersion"]).stdout.strip() or "unknown"
    except OSError:
        return "unknown"


def append_log(message: str, level: str = "INFO") -> Path:
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOG_DIR / "gui.log"
    stamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{stamp}][{level}] {message}\n"
    with log_file.open("a", encoding="utf-8") as handle:
        handle.write(line)
    return log_file


def system_metrics() -> dict:
    metrics = {
        "cpu": 0.0,
        "memory": 0.0,
        "disk": 0.0,
        "macos": read_macos_version(),
        "arch": platform.machine(),
        "apple_silicon": platform.machine() == "arm64",
    }
    if psutil is None:
        return metrics
    metrics["cpu"] = float(psutil.cpu_percent(interval=0.1))
    metrics["memory"] = float(psutil.virtual_memory().percent)
    metrics["disk"] = float(psutil.disk_usage("/").percent)
    return metrics


def backup_defaults_domains(label: str = "manual") -> Path:
    backup_root = BASE_DIR / "backups" / f"{datetime.now().strftime('%Y%m%d_%H%M%S')}_{label}"
    backup_root.mkdir(parents=True, exist_ok=True)
    domains = [
        "com.apple.dock",
        "com.apple.finder",
        "com.apple.universalaccess",
        "NSGlobalDomain",
    ]
    if is_macos():
        for domain in domains:
            target = backup_root / f"{domain}.plist"
            run_cmd(["defaults", "export", domain, str(target)])
    (backup_root / "README.txt").write_text(
        f"Backup created by macOS Optimizer GUI v{VERSION}\n", encoding="utf-8"
    )
    append_log(f"Backup created at {backup_root}")
    return backup_root


def optimize_graphics() -> str:
    if not is_macos():
        return "Skipped: graphics tweaks require macOS"
    commands = [
        ["defaults", "write", "com.apple.universalaccess", "reduceTransparency", "-bool", "true"],
        ["defaults", "write", "com.apple.universalaccess", "reduceMotion", "-bool", "true"],
        ["defaults", "write", "NSGlobalDomain", "NSAutomaticWindowAnimationsEnabled", "-bool", "false"],
        ["defaults", "write", "com.apple.dock", "autohide-time-modifier", "-float", "0.0"],
        ["defaults", "write", "com.apple.dock", "expose-animation-duration", "-float", "0.1"],
    ]
    ok = 0
    for cmd in commands:
        if run_cmd(cmd).returncode == 0:
            ok += 1
    run_cmd(["killall", "Dock"])
    msg = f"Graphics optimization applied ({ok}/{len(commands)} settings)"
    append_log(msg, "SUCCESS")
    return msg


def optimize_display() -> str:
    if not is_macos():
        return "Skipped: display tweaks require macOS"
    commands = [
        ["defaults", "write", "NSGlobalDomain", "AppleFontSmoothing", "-int", "1"],
        ["defaults", "write", "NSGlobalDomain", "CGFontRenderingFontSmoothingDisabled", "-bool", "NO"],
    ]
    ok = sum(1 for cmd in commands if run_cmd(cmd).returncode == 0)
    msg = f"Display optimization applied ({ok}/{len(commands)} settings)"
    append_log(msg, "SUCCESS")
    return msg


def optimize_storage() -> str:
    freed_hint = []
    cache_dir = Path.home() / "Library" / "Caches"
    removed = 0
    if cache_dir.is_dir():
        # Only clear a few well-known safe-ish cache roots; never touch system paths.
        candidates = [
            cache_dir / "com.apple.dt.Xcode",
            cache_dir / "Homebrew",
            cache_dir / "pip",
        ]
        for path in candidates:
            if path.exists():
                try:
                    shutil.rmtree(path, ignore_errors=True)
                    removed += 1
                    freed_hint.append(path.name)
                except OSError as exc:
                    append_log(f"Cache cleanup failed for {path}: {exc}", "WARNING")
    # User logs older than 14 days
    log_home = Path.home() / "Library" / "Logs"
    if log_home.is_dir():
        for path in log_home.rglob("*.log"):
            try:
                age_days = (datetime.now().timestamp() - path.stat().st_mtime) / 86400
                if age_days > 14 and path.is_file():
                    path.unlink(missing_ok=True)
                    removed += 1
            except OSError:
                continue
    msg = f"Storage cleanup finished ({removed} items). Targets: {', '.join(freed_hint) or 'logs/caches'}"
    append_log(msg, "SUCCESS")
    return msg


def optimize_network() -> str:
    if not is_macos():
        return "Skipped: network sysctl tweaks require macOS"
    params = [
        "net.inet.tcp.delayed_ack=0",
        "net.inet.tcp.mssdflt=1440",
        "net.inet.tcp.win_scale_factor=8",
    ]
    applied = 0
    for param in params:
        # Best-effort; may require sudo privileges outside GUI context.
        result = run_cmd(["sudo", "-n", "sysctl", "-w", param])
        if result.returncode != 0:
            result = run_cmd(["sysctl", "-w", param])
        if result.returncode == 0:
            applied += 1
    msg = f"Network optimization attempted ({applied}/{len(params)} applied)"
    append_log(msg, "SUCCESS" if applied else "WARNING")
    return msg


def optimize_performance() -> str:
    if not is_macos():
        return "Skipped: performance tweaks require macOS"
    notes = []
    # Preference-level responsiveness tweaks that do not need sudo
    prefs = [
        ["defaults", "write", "NSGlobalDomain", "NSWindowResizeTime", "-float", "0.001"],
        ["defaults", "write", "NSGlobalDomain", "DisableAllAnimations", "-bool", "true"],
    ]
    for cmd in prefs:
        if run_cmd(cmd).returncode == 0:
            notes.append(" ".join(cmd[2:4]))
    # Optional high-perf mode if passwordless sudo is available
    hp = run_cmd(["sudo", "-n", "pmset", "-a", "highperf", "1"])
    if hp.returncode == 0:
        notes.append("highperf=1")
    msg = "Performance tweaks applied: " + (", ".join(notes) if notes else "no changes (permissions?)")
    append_log(msg, "SUCCESS")
    return msg


OPTIMIZERS: dict[str, Callable[[], str]] = {
    "performance": optimize_performance,
    "graphics": optimize_graphics,
    "display": optimize_display,
    "storage": optimize_storage,
    "network": optimize_network,
}


class OptimizerApp:
    def __init__(self) -> None:
        self.status = "Ready"
        self.activity: List[str] = []
        self.cpu_bar: Optional[ui.linear_progress] = None
        self.mem_bar: Optional[ui.linear_progress] = None
        self.disk_bar: Optional[ui.linear_progress] = None
        self.status_label: Optional[ui.label] = None
        self.activity_column: Optional[ui.column] = None
        self.log_area: Optional[ui.textarea] = None
        self.page_containers: dict[str, ui.element] = {}
        self.busy = False

    def set_status(self, text: str) -> None:
        self.status = text
        if self.status_label is not None:
            self.status_label.set_text(f"Status: {text}")

    def push_activity(self, message: str) -> None:
        stamp = datetime.now().strftime("%H:%M:%S")
        entry = f"[{stamp}] {message}"
        self.activity.insert(0, entry)
        self.activity = self.activity[:50]
        append_log(message)
        if self.activity_column is not None:
            self.activity_column.clear()
            with self.activity_column:
                for item in self.activity[:12]:
                    ui.label(item).classes("text-sm text-grey-8")

    async def run_optimizer(self, key: str) -> None:
        if self.busy:
            ui.notify("Another task is already running", type="warning")
            return
        meta = OPTIMIZATION_CATEGORIES[key]
        if key != "storage" and not is_macos():
            ui.notify("This optimization requires macOS", type="negative")
            return
        self.busy = True
        self.set_status(f"Running {meta['label']}…")
        self.push_activity(f"Started: {meta['label']}")
        try:
            backup_defaults_domains(label=key)
            result = await asyncio.to_thread(OPTIMIZERS[key])
            self.push_activity(result)
            ui.notify(result, type="positive")
        except Exception as exc:  # noqa: BLE001 - surface to UI
            self.push_activity(f"Error: {exc}")
            ui.notify(str(exc), type="negative")
            append_log(str(exc), "ERROR")
        finally:
            self.busy = False
            self.set_status("Ready")

    async def run_all(self) -> None:
        for key in OPTIMIZATION_CATEGORIES:
            await self.run_optimizer(key)

    async def create_backup(self) -> None:
        path = await asyncio.to_thread(backup_defaults_domains, "manual")
        self.push_activity(f"Backup saved: {path}")
        ui.notify(f"Backup saved to {path}", type="positive")

    def refresh_logs(self) -> None:
        log_file = LOG_DIR / "gui.log"
        content = log_file.read_text(encoding="utf-8") if log_file.exists() else "No logs yet."
        if self.log_area is not None:
            self.log_area.value = content[-12000:]

    def clear_logs(self) -> None:
        log_file = LOG_DIR / "gui.log"
        if log_file.exists():
            log_file.write_text("", encoding="utf-8")
        self.refresh_logs()
        ui.notify("Logs cleared", type="info")

    def update_metrics(self) -> None:
        metrics = system_metrics()
        if self.cpu_bar is not None:
            self.cpu_bar.value = metrics["cpu"] / 100.0
        if self.mem_bar is not None:
            self.mem_bar.value = metrics["memory"] / 100.0
        if self.disk_bar is not None:
            self.disk_bar.value = metrics["disk"] / 100.0

    def show_page(self, name: str) -> None:
        for key, element in self.page_containers.items():
            element.set_visibility(key == name)

    def build(self) -> None:
        ui.colors(primary="#2563eb", secondary="#0f172a", accent="#7c3aed", positive="#16a34a")
        ui.dark_mode(True)

        with ui.header().classes("items-center justify-between px-4"):
            with ui.row().classes("items-center gap-2"):
                ui.icon("tune", size="md")
                ui.label(f"{GUI_TITLE} v{VERSION}").classes("text-h6")
            with ui.row().classes("items-center gap-2"):
                ui.button(icon="dark_mode", on_click=lambda: ui.dark_mode().toggle()).props("flat round")
                ui.button("Backup", icon="save", on_click=self.create_backup).props("flat")

        with ui.left_drawer(value=True).classes("p-4") as drawer:
            ui.label("Navigation").classes("text-bold q-mb-md")
            for key, label, icon in [
                ("dashboard", "Dashboard", "dashboard"),
                ("optimizations", "Optimizations", "bolt"),
                ("logs", "Logs", "article"),
                ("settings", "Settings", "settings"),
            ]:
                ui.button(label, icon=icon, on_click=lambda k=key: self.show_page(k)).props(
                    "flat align=left"
                ).classes("w-full")
            ui.separator()
            ui.label(f"Host: {read_macos_version()}").classes("text-caption")
            ui.label(f"Arch: {platform.machine()}").classes("text-caption")
            if not is_macos():
                ui.badge("Preview mode (non-macOS)").props("color=orange")

        with ui.footer().classes("px-4"):
            self.status_label = ui.label("Status: Ready")
            ui.space()
            ui.label("© 2026 macOS Optimizer").classes("text-caption")
            ui.link("GitHub", "https://github.com/samihalawa/macos-optimizer", new_tab=True)

        with ui.column().classes("w-full max-w-6xl mx-auto p-4 gap-4"):
            # Dashboard
            with ui.column().classes("w-full gap-4") as dash:
                self.page_containers["dashboard"] = dash
                ui.label("System overview").classes("text-h5")
                with ui.row().classes("w-full gap-4 flex-wrap"):
                    with ui.card().classes("flex-1 min-w-[220px]"):
                        ui.label("CPU").classes("text-subtitle2")
                        self.cpu_bar = ui.linear_progress(value=0, show_value=True)
                    with ui.card().classes("flex-1 min-w-[220px]"):
                        ui.label("Memory").classes("text-subtitle2")
                        self.mem_bar = ui.linear_progress(value=0, show_value=True)
                    with ui.card().classes("flex-1 min-w-[220px]"):
                        ui.label("Disk").classes("text-subtitle2")
                        self.disk_bar = ui.linear_progress(value=0, show_value=True)

                with ui.card().classes("w-full"):
                    ui.label("Quick actions").classes("text-subtitle1")
                    with ui.row().classes("gap-2 flex-wrap"):
                        ui.button("Run all safe tweaks", icon="play_arrow", on_click=self.run_all)
                        ui.button("Create backup", icon="save", on_click=self.create_backup)
                        ui.button("Refresh metrics", icon="refresh", on_click=self.update_metrics)

                with ui.card().classes("w-full"):
                    ui.label("Recent activity").classes("text-subtitle1")
                    self.activity_column = ui.column().classes("gap-1")
                    ui.label("No activity yet").classes("text-sm text-grey-7")

            # Optimizations
            with ui.column().classes("w-full gap-4") as opts:
                self.page_containers["optimizations"] = opts
                ui.label("Optimizations").classes("text-h5")
                ui.markdown(
                    "Each action creates a preference backup first. "
                    "Review [SECURITY.md](https://github.com/samihalawa/macos-optimizer/blob/main/SECURITY.md) "
                    "before bulk changes."
                )
                with ui.grid(columns=2).classes("w-full gap-4"):
                    for key, meta in OPTIMIZATION_CATEGORIES.items():
                        with ui.card().classes("w-full"):
                            with ui.row().classes("items-center gap-2"):
                                ui.icon(meta["icon"])
                                ui.label(meta["label"]).classes("text-subtitle1")
                            ui.label(meta["description"]).classes("text-sm")
                            ui.badge(meta["safety"]).props("outline")
                            ui.button(
                                "Run",
                                icon="play_arrow",
                                on_click=lambda k=key: self.run_optimizer(k),
                            ).classes("q-mt-sm")

            # Logs
            with ui.column().classes("w-full gap-4") as logs_page:
                self.page_containers["logs"] = logs_page
                ui.label("Logs").classes("text-h5")
                with ui.row().classes("gap-2"):
                    ui.button("Refresh", icon="refresh", on_click=self.refresh_logs)
                    ui.button("Clear", icon="delete", on_click=self.clear_logs)
                self.log_area = ui.textarea(value="No logs yet.").classes("w-full").props("readonly rows=20")

            # Settings
            with ui.column().classes("w-full gap-4") as settings_page:
                self.page_containers["settings"] = settings_page
                ui.label("Settings").classes("text-h5")
                with ui.card().classes("w-full"):
                    ui.label(f"Version: {VERSION}")
                    ui.label(f"Data directory: {BASE_DIR}")
                    ui.label(f"GUI bind: http://{GUI_HOST}:{GUI_PORT}")
                    ui.label(f"Platform: {platform.system()} {platform.release()} ({platform.machine()})")
                    ui.separator()
                    ui.markdown(
                        "**Safety tips**\n\n"
                        "- Prefer one category at a time on first use\n"
                        "- Keep Time Machine current\n"
                        "- Some sysctl values reset after reboot\n"
                        "- The GUI never sends data off-device"
                    )

        self.show_page("dashboard")
        self.update_metrics()
        ui.timer(3.0, self.update_metrics)
        # drawer kept referenced for potential future toggle
        _ = drawer


def main() -> None:
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    optimizer = OptimizerApp()
    optimizer.build()
    ui.run(
        title=f"{GUI_TITLE} v{VERSION}",
        host=GUI_HOST,
        port=GUI_PORT,
        reload=False,
        show=False,
        favicon="🚀",
    )


if __name__ in {"__main__", "__mp_main__"}:
    main()
