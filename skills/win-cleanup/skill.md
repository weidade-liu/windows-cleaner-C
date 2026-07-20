---
name: win-cleanup
description: Windows C 盘清理工具 —— 一键扫描并清理临时文件/应用缓存，安全可回溯
# 在项目目录下运行即可使用
---

# /win-cleanup

Windows C 盘清理工具，一键扫描并清理 C 盘高占用空间。

## 使用方式

在本项目根目录执行：

```
/win-cleanup
```

或直接运行脚本：

```bash
# 方法一：双击
clean.bat

# 方法二：PowerShell
powershell -ExecutionPolicy Bypass -File .\clean.ps1

# 方法三：仅扫描
powershell -ExecutionPolicy Bypass -File .\scan.ps1
```

## 功能

| 功能 | 说明 |
|------|------|
| 📊 扫描分析 | 分析 C 盘各目录占用空间排行 |
| 🧹 快速清理 | 安全删除临时文件、浏览器缓存、npm 缓存、回收站等 |
| 🧹 深度清理 | 清理 JetBrains/微信/QQ/剪映/虎牙等应用缓存 |
| 🔒 安全设计 | 只删除安全可删除的缓存/临时文件 |
| 📋 清理报告 | 显示释放了多少空间 |

## 清理内容

**安全清理（Safe）**：
- 系统临时文件（%TEMP%、C:\Windows\Temp）
- Chrome 浏览器缓存
- npm 缓存
- 回收站
- Windows 更新缓存
- Office 文件缓存

**深度清理（Warning）**：
- JetBrains IDE 缓存（重建索引）
- 剪映专业版缓存（重下素材）
- 微信/QQ 缓存（保留聊天记录）
- 虎牙直播缓存（重新登录）
- Edge 浏览器缓存

## 参数

```powershell
# 快速清理（仅安全项）
.\clean.ps1 -SafeOnly

# 深度清理（含应用缓存）
.\clean.ps1 -All

# 仅扫描（不清理）
.\clean.ps1 -ScanOnly

# 预览模式（不实际删除）
.\clean.ps1 -WhatIf
```

## 自定义清理

编辑 `src\modules.ps1` 中的 `$CleanupTasks` 数组，注释掉不想清理的项。

## 项目结构

```
win-cleanup-tool/
├── README.md              # 文档
├── clean.bat              # 批处理脚本（双击运行）
├── clean.ps1              # PowerShell 主脚本
├── scan.ps1               # 仅扫描分析
├── .gitignore
└── src/
    └── modules.ps1         # 清理模块定义
```

## 环境要求

- 系统：Windows 10 / Windows 11
- 权限：建议管理员（非管理员也可运行，清理范围受限）
- PowerShell 5.1+（Windows 自带）
