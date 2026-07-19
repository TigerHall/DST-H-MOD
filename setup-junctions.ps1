# DST-H-MOD 目录联接设置脚本
# 将游戏 mods 目录下的文件夹通过 Junction 指向项目源文件夹
# 实现「修改项目代码 = 即时同步到游戏」
#
# 使用方法：右键 -> 使用 PowerShell 运行
# 需要管理员权限（Junction 操作需要）

$ErrorActionPreference = "Stop"

# 路径配置 — 按需修改这里
$gameModsPath = "C:\Program Files (x86)\Steam\steamapps\common\Don't Starve Together\mods"
$projectPath = "C:\Users\hehu\Documents\GitHub\DST-H-MOD"

# MOD 对应关系表：@{
#     mods目录名 = 项目文件夹名
# }
$modMappings = @{
    "hcane"  = "行走手杖优化"
    "hslot"  = "格子优化"
    "hfood"  = "零食优化"
    "htree"  = "水中木优化"
    "htable" = "茶几优化"
    "hpack"  = "背包优化"
    "hh"     = "实验代码"   # ⚠️ 项目中没有"实验代码"文件夹，确认后修改或删除此行
    "hreturn" = "离线物品回收"
    "hpaper"  = "制图桌回收"
}

# ---------- 以下无需修改 ----------
function Set-ModJunction {
    param([string]$ModName, [string]$FolderName)

    $junctionPath = Join-Path $gameModsPath $ModName
    $sourcePath = Join-Path $projectPath $FolderName

    # 检查源文件夹是否存在
    if (-not (Test-Path $sourcePath)) {
        Write-Warning "⚠ 源文件夹不存在，跳过: $sourcePath"
        return $false
    }

    # 检查目标是否已存在
    if (Test-Path $junctionPath) {
        $item = Get-Item $junctionPath -Force
        if ($item.LinkType -eq "Junction") {
            Write-Host "✓ 已是指向项目目录的 Junction，跳过: $junctionPath" -ForegroundColor Green
            return $true
        }
        if ($item.LinkType -eq $null -or $item.LinkType -eq "SymbolicLink") {
            # 备份原文件夹
            $backupPath = "${junctionPath}_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Write-Host "→ 备份原文件夹到: $backupPath" -ForegroundColor Yellow
            Move-Item -Path $junctionPath -Destination $backupPath -Force
        }
    }

    try {
        New-Item -ItemType Junction -Path $junctionPath -Target $sourcePath -Force | Out-Null
        Write-Host "✅ 成功创建 Junction: $junctionPath → $sourcePath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ 创建失败: $_" -ForegroundColor Red
        return $false
    }
}

Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  DST-H-MOD 目录联接设置" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 确认提示
Write-Host "即将为以下 MOD 创建目录联接：" -ForegroundColor White
foreach ($entry in $modMappings.GetEnumerator()) {
    Write-Host "  $($entry.Key) → $($entry.Value)"
}
Write-Host ""
Write-Host "这会替换游戏 mods 目录下的原文件夹为项目源的链接。" -ForegroundColor Yellow
$confirm = Read-Host "是否继续？(y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "已取消。" -ForegroundColor Red
    exit
}

Write-Host ""
$successCount = 0
$totalCount = $modMappings.Count

foreach ($entry in $modMappings.GetEnumerator()) {
    Write-Host "→ 处理 $($entry.Key)..." -ForegroundColor White
    if (Set-ModJunction -ModName $entry.Key -FolderName $entry.Value) {
        $successCount++
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "完成: $successCount / $totalCount" -ForegroundColor Cyan
if ($successCount -lt $totalCount) {
    Write-Host "请检查上方警告信息，确认路径是否正确。" -ForegroundColor Yellow
}
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 提示：如果 Steam 正在运行，建议重启游戏以确保生效。" -ForegroundColor Cyan
