<#
.SYNOPSIS
    扫描 C 盘空间占用分析（仅扫描，不清理）
.DESCRIPTION
    分析 C 盘各目录占用空间大小，按从大到小排序输出。
    不会对系统做任何修改。
#>

$ErrorActionPreference = "SilentlyContinue"

# ---- 扫描目标列表 ----
$Targets = @(
    @{ Name = "系统 (Windows)";           Path = "C:\Windows" }
    @{ Name = "Program Files";            Path = "C:\Program Files" }
    @{ Name = "Program Files (x86)";      Path = "C:\Program Files (x86)" }
    @{ Name = "程序数据 (ProgramData)";    Path = "C:\ProgramData" }
    @{ Name = "用户数据 (Users)";          Path = "C:\Users" }
    @{ Name = "回收站";                    Path = 'C:\$Recycle.Bin' }
)

# ---- 用户目录细粒度扫描 ----
$UserPaths = @(
    @{ Name = "用户 AppData";            Path = "$env:USERPROFILE\AppData" }
    @{ Name = "用户 桌面";               Path = "$env:USERPROFILE\Desktop" }
    @{ Name = "用户 文档";               Path = "$env:USERPROFILE\Documents" }
    @{ Name = "用户 下载";               Path = "$env:USERPROFILE\Downloads" }
    @{ Name = "用户 图片";               Path = "$env:USERPROFILE\Pictures" }
    @{ Name = "用户 视频";               Path = "$env:USERPROFILE\Videos" }
    @{ Name = "用户 音乐";               Path = "$env:USERPROFILE\Music" }
)

# ---- AppData 细粒度扫描 ----
$AppDataPaths = @(
    @{ Name = "  Local\Temp";             Path = "$env:LOCALAPPDATA\Temp" }
    @{ Name = "  Local\Google (Chrome)";  Path = "$env:LOCALAPPDATA\Google" }
    @{ Name = "  Local\JetBrains";        Path = "$env:LOCALAPPDATA\JetBrains" }
    @{ Name = "  Local\Microsoft";        Path = "$env:LOCALAPPDATA\Microsoft" }
    @{ Name = "  Local\JianyingPro";      Path = "$env:LOCALAPPDATA\JianyingPro" }
    @{ Name = "  Local\npm-cache";        Path = "$env:LOCALAPPDATA\npm-cache" }
    @{ Name = "  Roaming\Tencent";        Path = "$env:APPDATA\Tencent" }
    @{ Name = "  Roaming\Notion";         Path = "$env:APPDATA\Notion" }
    @{ Name = "  Roaming\huyapclive";     Path = "$env:APPDATA\huyapclive" }
)

function Get-FolderSize {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $size = (Get-ChildItem $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                 Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return $size
    } catch { return $null }
}

function Format-Size {
    param([double]$Bytes)
    if ($null -eq $Bytes -or $Bytes -le 0) { return "0 B" }
    $units = @("B", "KB", "MB", "GB", "TB")
    $i = 0; $s = [double]$Bytes
    while ($s -ge 1024 -and $i -lt 4) { $s /= 1024; $i++ }
    return "{0:F2} {1}" -f $s, $units[$i]
}

# ════════════════════════════════════════════
Write-Host "`n" -NoNewline
Write-Host " ===== C 盘空间占用分析 (仅扫描) =====" -ForegroundColor Cyan
Write-Host "`n" -NoNewline

$drive = Get-PSDrive C
Write-Host " C 盘总容量: $([math]::Round($drive.Used/1GB,2)) GB / $([math]::Round(($drive.Used+$drive.Free)/1GB,2)) GB" -ForegroundColor Yellow
Write-Host " 可用空间: $([math]::Round($drive.Free/1GB,2)) GB" -ForegroundColor $(if ($drive.Free/1GB -lt 5){"Red"}elseif ($drive.Free/1GB -lt 15){"Yellow"}else{"Green"})
Write-Host "`n"

# 根目录扫描
Write-Host " >> C 盘根目录占用排行" -ForegroundColor Cyan
$results = @()
foreach ($t in $Targets) {
    $size = Get-FolderSize -Path $t.Path
    if ($null -ne $size) { $results += [PSCustomObject]@{Name=$t.Name;Size=$size;Str=Format-Size $size} }
}
$results | Sort-Object Size -Descending | ForEach-Object {
    $c = if ($_.Size -gt 10GB){"Red"}elseif($_.Size -gt 5GB){"Yellow"}else{"Green"}
    Write-Host ("  {0,-30} {1,10}" -f $_.Name, $_.Str) -ForegroundColor $c
}

# 用户目录
Write-Host "`n >> 用户目录 ($env:USERNAME)" -ForegroundColor Cyan
$uResults = @()
foreach ($t in $UserPaths) {
    $size = Get-FolderSize -Path $t.Path
    if ($null -ne $size -and $size -gt 0) { $uResults += [PSCustomObject]@{Name=$t.Name;Size=$size;Str=Format-Size $size} }
}
$uResults | Sort-Object Size -Descending | ForEach-Object {
    $c = if ($_.Size -gt 5GB){"Red"}elseif($_.Size -gt 1GB){"Yellow"}else{"Green"}
    Write-Host ("  {0,-30} {1,10}" -f $_.Name, $_.Str) -ForegroundColor $c
}

# AppData 细粒度
Write-Host "`n >> AppData 详细分析" -ForegroundColor Cyan
$aResults = @()
foreach ($t in $AppDataPaths) {
    $size = Get-FolderSize -Path $t.Path
    if ($null -ne $size -and $size -gt 0) { $aResults += [PSCustomObject]@{Name=$t.Name;Size=$size;Str=Format-Size $size} }
}
$aResults | Sort-Object Size -Descending | ForEach-Object {
    $c = if ($_.Size -gt 2GB){"Red"}elseif($_.Size -gt 500MB){"Yellow"}else{"Green"}
    Write-Host ("  {0,-35} {1,10}" -f $_.Name, $_.Str) -ForegroundColor $c
}

# 建议
Write-Host "`n >> 清理建议" -ForegroundColor Cyan
$bigOnes = $aResults | Where-Object { $_.Size -gt 1GB }
if ($bigOnes.Count -gt 0) {
    $total = ($bigOnes | Measure-Object -Property Size -Sum).Sum
    Write-Host "  以下目录可考虑清理 (合计 $(Format-Size $total)):" -ForegroundColor Yellow
    foreach ($b in $bigOnes) { Write-Host "    o $($b.Name) ($($b.Str))" -ForegroundColor Yellow }
    Write-Host "`n  运行 .\clean.ps1 执行清理" -ForegroundColor Green
} else {
    Write-Host "  C 盘空间充足, 无需清理" -ForegroundColor Green
}
Write-Host "`n =====`n" -ForegroundColor Cyan
