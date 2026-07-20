<#
.SYNOPSIS
    清理模块定义 - 供 clean.ps1 调用
.DESCRIPTION
    定义各清理任务的路径、分类和清理函数。
    通过 $CleanupTasks 数组统一管理所有清理项。
#>

# 安全等级说明
#   Safe    = 删除后系统/应用自动重建，无副作用
#   Warning = 删除后可能需要重新登录/下载/索引

# ── 清理任务定义 ──────────────────────────────────────────
$CleanupTasks = @(
    # ─── 安全清理 (SafeOnly) ───
    @{
        Name     = "系统临时文件"
        Path     = @("$env:TEMP", "$env:SystemRoot\Temp")
        Category = "Safe"
        Recurse  = $true
        Exclude  = @()
        Note     = "系统/应用运行时产生的临时文件"
    }
    @{
        Name     = "Chrome 浏览器缓存"
        Path     = @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
                     "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache")
        Category = "Safe"
        Recurse  = $true
        Exclude  = @()
        Note     = "浏览器缓存，清后自动重建"
    }
    @{
        Name     = "npm 缓存"
        Path     = @("$env:LOCALAPPDATA\npm-cache")
        Category = "Safe"
        Recurse  = $true
        Exclude  = @()
        Note     = "Node.js 包缓存"
    }
    @{
        Name     = "回收站 ($Recycle.Bin)"
        Path     = @("C:\`$Recycle.Bin")
        Category = "Safe"
        Recurse  = $true
        Exclude  = @()
        Note     = "回收站中的已删除文件"
    }
    @{
        Name     = "Windows 更新缓存"
        Path     = @("$env:SystemRoot\SoftwareDistribution\Download")
        Category = "Safe"
        Recurse  = $true
        Exclude  = @()
        Note     = "Windows Update 下载的安装包"
    }
    @{
        Name     = "Delivery Optimization 缓存"
        Path     = @("$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache")
        Category = "Safe"
        Recurse  = $true
        Exclude  = @()
        Note     = "Windows 更新对等缓存"
    }
    @{
        Name     = "Office 缓存"
        Path     = @("$env:LOCALAPPDATA\Microsoft\Office\16.0\OfficeFileCache")
        Category = "Safe"
        Recurse  = $true
        Exclude  = @()
        Note     = "Office 文档缓存"
    }
    @{
        Name     = "回收站 (每个用户的)"
        Path     = @("$env:SystemDrive\`$Recycle.Bin")
        Category = "Safe"
        Recurse  = $true
        Exclude  = @()
        Note     = "清空所有用户的回收站（需管理员）"
    }

    # ─── 深度清理 (All / 需确认) ───
    @{
        Name     = "JetBrains IDE 缓存"
        Path     = @("$env:LOCALAPPDATA\JetBrains")
        Category = "Warning"
        Recurse  = $true
        Exclude  = @("*.cfg", "*.xml", "*.vmoptions", "*.properties")
        Note     = "IDE 索引和缓存，重开后重建索引"
    }
    @{
        Name     = "剪映专业版缓存"
        Path     = @("$env:LOCALAPPDATA\JianyingPro\Cache",
                     "$env:LOCALAPPDATA\JianyingPro\Resources")
        Category = "Warning"
        Recurse  = $true
        Exclude  = @()
        Note     = "视频渲染临时文件和素材缓存"
    }
    @{
        Name     = "微信缓存"
        Path     = @("$env:LOCALAPPDATA\Tencent\WeChat",
                     "$env:APPDATA\Tencent\WeChat")
        Category = "Warning"
        Recurse  = $true
        Exclude  = @("*.db", "*.db-journal", "*.dat", "MSG*", "MicroMsg.db")
        Note     = "微信聊天记录缓存（保留聊天记录数据库）"
    }
    @{
        Name     = "QQ 缓存"
        Path     = @("$env:LOCALAPPDATA\Tencent\QQBrowser",
                     "$env:LOCALAPPDATA\Tencent\QQ",
                     "$env:APPDATA\Tencent\QQ")
        Category = "Warning"
        Recurse  = $true
        Exclude  = @("*.db", "*.db-journal", "Msg*.db")
        Note     = "QQ 缓存文件（保留聊天记录）"
    }
    @{
        Name     = "虎牙直播缓存"
        Path     = @("$env:APPDATA\huyapclive")
        Category = "Warning"
        Recurse  = $true
        Exclude  = @()
        Note     = "直播缓存，需重新登录"
    }
    @{
        Name     = "Edge 浏览器缓存"
        Path     = @("$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
                     "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache")
        Category = "Warning"
        Recurse  = $true
        Exclude  = @()
        Note     = "Edge 浏览器缓存，清后自动重建"
    }
    @{
        Name     = "Notion 缓存"
        Path     = @("$env:APPDATA\Notion")
        Category = "Warning"
        Recurse  = $true
        Exclude  = @()
        Note     = "Notion 应用缓存"
    }
)


# ── 工具函数 ────────────────────────────────────────────────

function Get-FolderSize {
    <#
    .SYNOPSIS
        计算文件夹总大小（递归）
    #>
    param(
        [string]$Path,
        [switch]$Force
    )
    if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) { return $null }
    try {
        $opts = @{ Recurse = $true; File = $true; ErrorAction = "SilentlyContinue" }
        if ($Force) { $opts.Force = $true }
        $size = (Get-ChildItem $Path @opts |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return $size
    } catch { return $null }
}

function Format-Size {
    <#
    .SYNOPSIS
        将字节数转为人类可读的尺寸字符串
    #>
    param([double]$Bytes)
    if ($null -eq $Bytes -or $Bytes -le 0) { return "0 B" }
    $units = @("B", "KB", "MB", "GB", "TB")
    $i = 0; $s = [double]$Bytes
    while ($s -ge 1024 -and $i -lt 4) { $s /= 1024; $i++ }
    return "{0:F2} {1}" -f $s, $units[$i]
}

function Format-Duration {
    <#
    .SYNOPSIS
        将秒数转为人类可读的时长字符串
    #>
    param([double]$Seconds)
    if ($Seconds -lt 60)  { return "{0:F0} 秒" -f $Seconds }
    if ($Seconds -lt 3600) {
        $m = [math]::Floor($Seconds / 60)
        $s = $Seconds % 60
        return "{0} 分 {1:F0} 秒" -f $m, $s
    }
    $h  = [math]::Floor($Seconds / 3600)
    $m  = [math]::Floor(($Seconds % 3600) / 60)
    $s  = $Seconds % 60
    return "{0} 时 {1} 分 {2:F0} 秒" -f $h, $m, $s
}

function Initialize-AdminCheck {
    <#
    .SYNOPSIS
        检查是否以管理员权限运行
    #>
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-CleanupTask {
    <#
    .SYNOPSIS
        执行单个清理任务
    .DESCRIPTION
        递归删除指定路径下的所有文件和子目录（保留 Exclude 匹配的文件）。
        返回：@{ Success = $true/false; DeletedBytes = <int>; DeletedCount = <int> }
    #>
    param(
        [hashtable]$Task,
        [switch]$WhatIf
    )

    $result = @{ Success = $false; DeletedBytes = 0; DeletedCount = 0; ErrorMessage = "" }

    # 计算各路径大小的总和（清理前）
    $totalBefore = 0
    $validPaths = @()
    foreach ($p in $Task.Path) {
        if (Test-Path $p -ErrorAction SilentlyContinue) {
            $sz = Get-FolderSize -Path $p -Force
            if ($null -ne $sz) { $totalBefore += $sz }
            $validPaths += $p
        }
    }

    if ($validPaths.Count -eq 0) {
        $result.Success = $true
        return $result
    }

    try {
        foreach ($p in $validPaths) {
            if ($WhatIf) {
                Write-Host "    [WhatIf] 将清理: $p" -ForegroundColor DarkGray
                continue
            }

            # 如果路径是回收站，使用专门的清空命令
            if ($p -match '\$Recycle\.Bin') {
                try {
                    # 清空回收站
                    $shell = New-Object -ComObject Shell.Application
                    $shell.NameSpace(0xa).Items() | ForEach-Object {
                        $shell.NameSpace(0xa).GetItems() | ForEach-Object { $_.InvokeVerb("delete") }
                    }
                    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
                    $result.Success = $true
                    # 无法精确计算回收站释放的空间，用之前计算的值
                } catch {
                    # 如果 COM 方式失败，尝试用 cmd 方式
                    & cmd.exe /c "rd /s /q `"$p`"" 2>$null
                }
                continue
            }

            # 删除文件
            $files = Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue | `
                     Where-Object { $_.PSIsContainer -eq $false }

            # 应用排除模式
            if ($Task.Exclude.Count -gt 0) {
                $files = $files | Where-Object {
                    $exclude = $false
                    foreach ($pattern in $Task.Exclude) {
                        if ($_.Name -like $pattern) { $exclude = $true; break }
                    }
                    -not $exclude
                }
            }

            $fileCount = 0
            $fileBytes = 0
            foreach ($f in $files) {
                try {
                    $fileBytes += $f.Length
                    Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
                    $fileCount++
                } catch { }
            }

            # 删除空目录
            $dirs = Get-ChildItem $p -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                    Sort-Object FullName -Descending
            foreach ($d in $dirs) {
                try {
                    Remove-Item -Path $d.FullName -Force -ErrorAction SilentlyContinue
                } catch { }
            }

            $result.DeletedBytes += $fileBytes
            $result.DeletedCount += $fileCount
        }

        # 如果删掉了内容但之前的计数为0，用前后差值估算
        if ($result.DeletedBytes -eq 0 -and $totalBefore -gt 0) {
            $totalAfter = 0
            foreach ($p in $validPaths) {
                if (Test-Path $p -ErrorAction SilentlyContinue) {
                    $sz = Get-FolderSize -Path $p -Force
                    if ($null -ne $sz) { $totalAfter += $sz }
                }
            }
            $result.DeletedBytes = [math]::Max(0, $totalBefore - $totalAfter)
            if ($result.DeletedBytes -gt 0) { $result.DeletedCount = 999 }  # 估算标记
        }

        $result.Success = $true
    } catch {
        $result.ErrorMessage = $_.Exception.Message
        $result.Success = $false
    }

    return $result
}
