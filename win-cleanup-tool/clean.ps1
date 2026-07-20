<#
.SYNOPSIS
    Windows C 盘清理工具 - PowerShell 入口
.DESCRIPTION
    加载 modules.ps1 并执行清理任务。
    支持安全清理 (-SafeOnly) 和深度清理 (-All) 两种模式。

.PARAMETER SafeOnly
    只清理安全的临时文件和缓存（默认）
.PARAMETER All
    执行深度清理，包括应用缓存（JetBrains、微信、QQ、剪映等）
.PARAMETER ScanOnly
    只扫描分析空间占用，不执行清理
.PARAMETER WhatIf
    预览模式，只显示将要清理的内容但不实际删除

.EXAMPLE
    .\clean.ps1 -SafeOnly
    .\clean.ps1 -All
    .\clean.ps1 -WhatIf
#>

param(
    [switch]$SafeOnly,
    [switch]$All,
    [switch]$ScanOnly,
    [switch]$WhatIf
)

$ErrorActionPreference = "Continue"
$scriptPath = Split-Path -Parent $PSCommandPath

# ── 加载模块 ────────────────────────────────────────────────
. "$scriptPath\src\modules.ps1"

# ── 启动标题 ────────────────────────────────────────────────
function Show-Banner {
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        Windows C 盘清理工具 v1.0              ║" -ForegroundColor Cyan
    Write-Host "║        安全 · 高效 · 可回溯                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $isAdmin = Initialize-AdminCheck
    if (-not $isAdmin) {
        Write-Host " ⚠ 未以管理员身份运行，部分系统文件可能无法清理" -ForegroundColor Yellow
        Write-Host "   建议：右键 PowerShell → 以管理员身份运行`n" -ForegroundColor Yellow
    }

    $drive = Get-PSDrive C -ErrorAction SilentlyContinue
    if ($drive) {
        $totalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 1)
        $freeGB  = [math]::Round($drive.Free / 1GB, 1)
        $usedGB  = [math]::Round($drive.Used / 1GB, 1)
        Write-Host " C 盘: $usedGB GB / $totalGB GB 已用, 剩余 $freeGB GB" -ForegroundColor $(
            if ($freeGB -lt 5) { "Red" }
            elseif ($freeGB -lt 15) { "Yellow" }
            else { "Green" }
        )
        Write-Host ""
    }
}

# ── 扫描分析 ────────────────────────────────────────────────
function Invoke-ScanAnalysis {
    param([switch]$ShowBanner)

    if ($ShowBanner) { Show-Banner }

    Write-Host " 📊 正在分析 C 盘空间占用..." -ForegroundColor Cyan
    Write-Host ""

    # 获取各清理任务的当前大小
    $results = @()
    foreach ($task in $CleanupTasks) {
        $totalSize = 0
        $hasPath = $false
        foreach ($p in $task.Path) {
            if (Test-Path $p -ErrorAction SilentlyContinue) {
                $hasPath = $true
                $sz = Get-FolderSize -Path $p -Force
                if ($null -ne $sz) { $totalSize += $sz }
            }
        }
        if ($hasPath) {
            $results += [PSCustomObject]@{
                Name     = $task.Name
                Size     = $totalSize
                SizeStr  = Format-Size $totalSize
                Category = $task.Category
            }
        }
    }

    # 排序输出
    $sorted = $results | Sort-Object Size -Descending
    Write-Host " ┌─────────────────────────────────────┬────────────┬──────────┐" -ForegroundColor DarkGray
    Write-Host " │ 清理项                               │ 占用空间   │ 安全等级 │" -ForegroundColor DarkGray
    Write-Host " ├─────────────────────────────────────┼────────────┼──────────┤" -ForegroundColor DarkGray
    foreach ($r in $sorted) {
        $color = if ($r.Size -gt 2GB) { "Red" } elseif ($r.Size -gt 500MB) { "Yellow" } else { "Green" }
        $catIcon = if ($r.Category -eq "Safe") { " ✅" } else { " ⚠" }
        Write-Host (" │ {0,-35} │ {1,10} │ {2,6} │" -f $r.Name, $r.SizeStr, $catIcon) -ForegroundColor $color
    }
    Write-Host " └─────────────────────────────────────┴────────────┴──────────┘" -ForegroundColor DarkGray

    $totalCleanable = ($sorted | Measure-Object -Property Size -Sum).Sum
    $safeCleanable  = ($sorted | Where-Object { $_.Category -eq "Safe" } | Measure-Object -Property Size -Sum).Sum

    Write-Host ""
    Write-Host " 可清理空间总计: $(Format-Size $totalCleanable)" -ForegroundColor Cyan
    Write-Host "   其中安全清理: $(Format-Size $safeCleanable)" -ForegroundColor Green
    Write-Host "   深度清理:     $(Format-Size ($totalCleanable - $safeCleanable))" -ForegroundColor Yellow
    Write-Host ""

    return @{
        TotalCleanable = $totalCleanable
        SafeCleanable  = $safeCleanable
        Items          = $sorted
    }
}

# ── 执行清理 ────────────────────────────────────────────────
function Invoke-Cleanup {
    param(
        [switch]$DeepClean,
        [switch]$WhatIf
    )

    Show-Banner

    $modeName = if ($DeepClean) { "深度清理" } else { "快速清理" }
    $modeIcon = if ($DeepClean) { "🧹" } else { "🧹" }
    Write-Host " $modeIcon 开始 $modeName ..." -ForegroundColor Cyan
    Write-Host ""

    if ($DeepClean) {
        Write-Host " ⚠ 深度清理将删除应用缓存数据。" -ForegroundColor Yellow
        Write-Host "   聊天记录不会丢失，但需重新登录和加载。`n" -ForegroundColor Yellow
    }

    # 选择要执行的任务
    $tasks = if ($DeepClean) {
        $CleanupTasks  # 全部
    } else {
        $CleanupTasks | Where-Object { $_.Category -eq "Safe" }
    }

    $totalTasks = $tasks.Count
    $completed  = 0
    $totalFreed = 0
    $totalFiles = 0
    $errorTasks = @()

    # 非 WhatIf 模式下预扫描
    if (-not $WhatIf) {
        Write-Host " ┌──────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
        foreach ($task in $tasks) {
            $completed++
            $pct = [math]::Round($completed / $totalTasks * 100)
            $name = $task.Name.PadRight(30).Substring(0, 30)
            Write-Host (" │ [{0,-3}/{1,-3}] {2} " -f $completed, $totalTasks, $name) -NoNewline -ForegroundColor DarkGray

            # 计算清理前大小
            $beforeSize = 0
            foreach ($p in $task.Path) {
                if (Test-Path $p -ErrorAction SilentlyContinue) {
                    $sz = Get-FolderSize -Path $p -Force
                    if ($null -ne $sz) { $beforeSize += $sz }
                }
            }

            if ($beforeSize -eq 0 -and (Test-Path $task.Path[0] -ErrorAction SilentlyContinue)) {
                Write-Host " 0 B  " -ForegroundColor Gray
                continue
            }

            if ($beforeSize -eq 0) {
                Write-Host " ∅    " -ForegroundColor Gray
                continue
            }

            $result = Invoke-CleanupTask -Task $task
            if ($result.Success) {
                $totalFreed += $result.DeletedBytes
                $totalFiles += $result.DeletedCount
                Write-Host " ✓ $(Format-Size $result.DeletedBytes)" -ForegroundColor Green
            } else {
                $errorTasks += $task.Name
                Write-Host " ✗ 失败" -ForegroundColor Red
            }
        }
        Write-Host " └──────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    } else {
        # WhatIf 模式：预览
        Write-Host " ┌──────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
        Write-Host " │ [预览模式] 以下是将要清理的内容：                        │" -ForegroundColor Yellow
        Write-Host " └──────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
        Write-Host ""
        foreach ($task in $tasks) {
            $beforeSize = 0
            foreach ($p in $task.Path) {
                if (Test-Path $p -ErrorAction SilentlyContinue) {
                    $sz = Get-FolderSize -Path $p -Force
                    if ($null -ne $sz) { $beforeSize += $sz }
                }
            }
            if ($beforeSize -gt 0) {
                $cat = if ($task.Category -eq "Safe") { "✅ 安全" } else { "⚠️ 注意" }
                Write-Host ("   {0,-35} {1,10}  {2}" -f $task.Name, (Format-Size $beforeSize), $cat) -ForegroundColor Cyan
            }
        }
    }

    # ── 清理报告 ──
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              清理完成报告                       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host ""
        Write-Host " 此模式仅预览，未执行任何清理操作。" -ForegroundColor Yellow
        Write-Host " 执行实际清理请不加 -WhatIf 参数运行："
        Write-Host "   .\clean.ps1 -SafeOnly" -ForegroundColor Green
        Write-Host "   .\clean.ps1 -All" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host " 清理模式    : $modeName" -ForegroundColor White
        Write-Host " 释放空间    : $(Format-Size $totalFreed)" -ForegroundColor Green
        Write-Host " 删除文件数  : $totalFiles 个" -ForegroundColor $(
            if ($totalFiles -le 0) { "Gray" } else { "Green" }
        )

        if ($errorTasks.Count -gt 0) {
            Write-Host ""
            Write-Host " ⚠ 以下任务执行出错：" -ForegroundColor Yellow
            foreach ($e in $errorTasks) { Write-Host "   - $e" -ForegroundColor Yellow }
        }

        # 清理后磁盘状态
        $drive = Get-PSDrive C -ErrorAction SilentlyContinue
        if ($drive) {
            $afterFree = [math]::Round($drive.Free / 1GB, 2)
            Write-Host ""
            Write-Host " C 盘剩余空间: $afterFree GB" -ForegroundColor $(
                if ($afterFree -lt 5) { "Red" } elseif ($afterFree -lt 15) { "Yellow" } else { "Green" }
            )
        }
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════
#  主入口
# ═══════════════════════════════════════════════════════════

# 如果没有参数，进入交互菜单
if (-not $SafeOnly -and -not $All -and -not $ScanOnly -and -not $WhatIf) {
    Show-Banner
    Write-Host " 请选择操作：" -ForegroundColor White
    Write-Host ""
    Write-Host "   [1] 快速清理（临时文件/缓存，安全）" -ForegroundColor Green
    Write-Host "   [2] 深度清理（含应用缓存，如微信/QQ/剪映等）" -ForegroundColor Yellow
    Write-Host "   [3] 仅扫描分析（不清理）" -ForegroundColor Cyan
    Write-Host "   [4] 预览模式（看清理内容但不删除）" -ForegroundColor DarkGray
    Write-Host ""
    $choice = Read-Host " 请输入选项 (1/2/3/4)"
    Write-Host ""

    switch ($choice) {
        "1" { Invoke-Cleanup -WhatIf:$WhatIf }
        "2" { Invoke-Cleanup -DeepClean -WhatIf:$WhatIf }
        "3" { $null = Invoke-ScanAnalysis; Write-Host " 按任意键退出..."; $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }
        "4" { Invoke-Cleanup -WhatIf }
        default {
            Write-Host " 无效选项，退出" -ForegroundColor Red
        }
    }
    exit
}

# 带参数运行
if ($ScanOnly) {
    $null = Invoke-ScanAnalysis -ShowBanner
}
elseif ($All) {
    Invoke-Cleanup -DeepClean -WhatIf:$WhatIf
}
else {
    # 默认 SafeOnly
    Invoke-Cleanup -WhatIf:$WhatIf
}
