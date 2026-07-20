# 🧹 Windows C 盘清理工具

一键扫描并清理 Windows C 盘高占用空间，安全、可回溯。

## 功能

- 📊 **扫描分析** C 盘各目录占用空间排行
- 🧹 **一键清理** 临时文件、应用缓存、回收站等
- 🔒 **安全设计** 只清理安全可删除的缓存/临时文件
- 📋 **清理报告** 显示释放了多少空间

## 快速使用

### 方法一：双击运行（推荐）

```bat
# 右键以管理员身份运行 clean.bat
clean.bat
```

### 方法二：PowerShell

```powershell
# 以管理员身份运行 PowerShell，执行：
.\clean.ps1
```

### 方法三：命令行

```bat
# 管理员 cmd 或 PowerShell 中执行：
clean.bat
```

## 清理内容

| 清理项 | 路径 | 说明 | 安全等级 |
|--------|------|------|----------|
| 系统临时文件 | `%TEMP%`, `C:\Windows\Temp` | 系统/应用运行时产生的临时文件 | ✅ 安全 |
| Chrome 缓存 | `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache` | 浏览器缓存，清后自动重建 | ✅ 安全 |
| npm 缓存 | `%LOCALAPPDATA%\npm-cache` | Node.js 包缓存 | ✅ 安全 |
| 回收站 | `C:\$Recycle.Bin` | 已删除文件 | ✅ 安全 |
| JetBrains IDE 缓存 | `%LOCALAPPDATA%\JetBrains` | IDE 索引和缓存 | ⚠️ 重建设索引 |
| 剪映缓存 | `%LOCALAPPDATA%\JianyingPro\Cache` | 视频渲染临时文件 | ⚠️ 重下素材 |
| 腾讯系缓存 | `%APPDATA%\Tencent\WeChat\` 等 | 微信/QQ 聊天缓存 | ⚠️ 保留聊天记录 |
| 虎牙直播 | `%APPDATA%\huyapclive\` | 直播缓存 | ⚠️ 需重新登录 |

> ⚠️ **注意**：清理腾讯系缓存不会删除聊天记录，但首次打开需重新加载历史消息。

## 项目结构

```
win-cleanup-tool/
├── README.md              # 本文档
├── clean.bat              # 批处理脚本（双击运行）
├── clean.ps1              # PowerShell 脚本
├── scan.ps1               # 仅扫描分析（不执行清理）
└── src/
    └── modules.ps1         # 各清理模块定义
```

## 手动扫描（不清理）

如果只想看 C 盘空间占用分析，不执行清理：

```powershell
.\scan.ps1
```

会输出类似：
```
=== C 盘空间占用排行 ===
Temp              : 4.56 GB
Chrome Cache      : 5.04 GB
JetBrains         : 2.71 GB
...
```

## 自定义清理

编辑 `src\modules.ps1` 中的 `$CleanupTasks` 数组，注释掉不想清理的项：

```powershell
$CleanupTasks = @(
    #@{ Name = "JetBrains"; Path = "$env:LOCALAPPDATA\JetBrains" }  # 注释掉这行
    @{ Name = "npm-cache"; Path = "$env:LOCALAPPDATA\npm-cache" }
)
```

## 环境要求

- 系统：Windows 10 / Windows 11
- 权限：建议以管理员身份运行（不是必须，但可清理更多）
- PowerShell：5.1+（Windows 自带的即可）

## 许可证

MIT
