# macOS Optimizer — 中文指南

<img width="100%" alt="GUI 截图" src="../images/gui-screenshot.png" />

## 简介

macOS Optimizer 提供两种界面：

1. **CLI**：终端交互菜单（`cli/src/macos-optimizer.sh`）
2. **GUI**：基于 NiceGUI 的本地网页面板（`gui/src/app.py`）

设计原则：**先备份**、**可解释**、**无遥测**。

## 快速开始

### CLI

```bash
chmod +x cli/src/macos-optimizer.sh
./cli/src/macos-optimizer.sh
```

### GUI

```bash
cd gui && python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python src/app.py
```

浏览器打开 `http://127.0.0.1:8080`。

## 优化类别

| 类别 | 说明 |
|---|---|
| 性能 | 响应相关偏好；可选高性能电源模式 |
| 图形界面 | 降低透明/动态效果，加快动画 |
| 显示 | 字体平滑等显示偏好 |
| 存储 | 清理部分用户缓存与旧日志 |
| 网络 | TCP 相关 `sysctl`（重启后可能恢复） |

## 安全建议

1. 先做 Time Machine 或其他完整备份  
2. 使用内置 **Backup**  
3. 首次逐项应用并观察  
4. 再考虑一键全部优化  

## 本地数据

数据目录：`~/.mac_optimizer/`（备份、日志、配置）。

## 许可证

MIT，详见仓库根目录 `LICENSE`。
