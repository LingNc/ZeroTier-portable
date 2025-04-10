# ZeroTier便携版Planet文件替换工具
# 此脚本用于替换ZeroTier的Planet文件，支持从网络下载或使用本地文件
# 作者: GitHub Copilot
# 版本: 1.1.0
# 日期: 2025-04-10

# 需要管理员权限
#Requires -RunAsAdministrator

# 参数定义
param (
    [switch]$help = $false,
    [switch]$h = $false
)

# 显示帮助信息
function Show-Help {
    Write-Host @"
===================================================
      ZeroTier Planet文件替换工具 - 帮助信息
      版本: 1.1.0
===================================================

描述:
    该脚本用于管理ZeroTier的Planet文件，允许替换为自定义的根服务器配置。
    Planet文件决定了ZeroTier网络的根服务器地址，适用于自建或使用第三方根服务器。

用法:
    planet-replace.ps1 [-help|-h]

参数:
    -help, -h    显示此帮助信息

功能:
    1. 从网络下载 - 从提供的URL下载Planet文件并替换
    2. 使用本地文件 - 从本地文件系统选择Planet文件替换
    3. 查看当前Planet信息 - 显示当前使用的Planet文件信息
    4. 恢复默认Planet - 删除自定义Planet文件，使用ZeroTier默认服务器

注意:
    - 此脚本需要管理员权限运行
    - 更改Planet服务器会影响网络连接性，请确保使用可信来源的配置

相关命令:
    也可通过 'zerotier-cli replace' 从任何位置启动此工具
"@
    exit 0
}

# 检查是否显示帮助
if ($help -or $h) {
    Show-Help
}

# 显示标题
Write-Host @"
===================================================
      ZeroTier 便携版 Planet 文件替换工具
      版本: 1.1.0
      日期: 2025-04-10
===================================================
"@ -ForegroundColor Cyan

# 获取脚本所在目录
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
# 获取根目录（当前目录的父目录）
$rootPath = Split-Path -Parent $scriptPath
$binPath = Join-Path -Path $rootPath -ChildPath "bin"
$dataPath = Join-Path -Path $rootPath -ChildPath "data"
$zerotierExe = Join-Path -Path $binPath -ChildPath "zerotier-one_x64.exe"
$planetFile = Join-Path -Path $dataPath -ChildPath "planet"

# 检查组件是否存在
if (-not (Test-Path $zerotierExe)) {
    Write-Host "错误：无法找到ZeroTier可执行文件: $zerotierExe" -ForegroundColor Red
    Write-Host "请确保文件结构完整，bin目录下包含所有必要文件。" -ForegroundColor Red
    Read-Host "按Enter退出"
    exit 1
}

# 确保数据目录存在
if (-not (Test-Path $dataPath)) {
    Write-Host "创建数据目录: $dataPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
}

# 菜单选择
Write-Host "`n请选择 Planet 文件来源:" -ForegroundColor Yellow
Write-Host "1. 从网络下载" -ForegroundColor Green
Write-Host "2. 使用本地文件" -ForegroundColor Green
Write-Host "3. 查看当前Planet信息" -ForegroundColor Green
Write-Host "4. 恢复默认Planet" -ForegroundColor Green
Write-Host "5. 退出" -ForegroundColor Red

$choice = Read-Host "`n请输入选项 (1-5)"

# 查看当前Planet信息
function Show-PlanetInfo {
    if (-not (Test-Path $planetFile)) {
        Write-Host "当前未找到Planet文件: $planetFile" -ForegroundColor Yellow
        Write-Host "这意味着ZeroTier将使用默认内置的Planet服务器。" -ForegroundColor Cyan
        return
    }

    # 尝试分析Planet文件内容
    Write-Host "Planet文件信息:" -ForegroundColor Cyan
    Write-Host "路径: $planetFile" -ForegroundColor Yellow
    Write-Host "大小: $((Get-Item $planetFile).Length) 字节" -ForegroundColor Yellow
    Write-Host "修改时间: $((Get-Item $planetFile).LastWriteTime)" -ForegroundColor Yellow

    # 可以尝试使用ZeroTier工具查看Planet详细信息
    # 但这依赖于ZeroTier提供此功能，如果不支持则跳过
    try {
        $planetInfo = & "$zerotierExe" -i dumpplanets "$planetFile" 2>&1
        if ($planetInfo -and $planetInfo -notmatch "error") {
            Write-Host "`nPlanet详细信息:" -ForegroundColor Cyan
            Write-Host $planetInfo
        }
    }
    catch {
        Write-Host "无法读取Planet详细信息" -ForegroundColor Red
    }
}

# 恢复默认Planet
function Restore-DefaultPlanet {
    if (Test-Path $planetFile) {
        # 备份现有文件
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = "$planetFile.bak-$timestamp"

        try {
            Copy-Item -Path $planetFile -Destination $backupFile -Force
            Write-Host "已备份当前Planet文件到: $backupFile" -ForegroundColor Green

            # 删除Planet文件以恢复默认设置
            Remove-Item -Path $planetFile -Force
            Write-Host "已删除自定义Planet文件，将使用ZeroTier默认Planet。" -ForegroundColor Green
        }
        catch {
            Write-Host "恢复默认Planet失败: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host "未找到自定义Planet文件，当前已在使用默认Planet。" -ForegroundColor Yellow
    }
}

# 处理菜单选择
switch ($choice) {
    "1" { # 从网络下载
        $downloadUrl = Read-Host "请输入Planet文件的下载URL"

        # 简单验证URL格式
        if (-not ($downloadUrl -match "^https?://")) {
            Write-Host "错误: URL必须以http://或https://开头" -ForegroundColor Red
            Read-Host "按Enter退出"
            exit 1
        }

        # 设置临时文件
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $tempFile = Join-Path -Path $env:TEMP -ChildPath "zerotier-planet-$timestamp"

        # 下载文件
        Write-Host "正在从 $downloadUrl 下载文件..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -ErrorAction Stop
        }
        catch {
            Write-Host "下载文件失败: $_" -ForegroundColor Red
            if (Test-Path $tempFile) { Remove-Item -Path $tempFile -Force }
            Read-Host "按Enter退出"
            exit 1
        }

        # 检查下载文件是否为空
        if ((Get-Item $tempFile).Length -eq 0) {
            Write-Host "错误: 下载的文件为空!" -ForegroundColor Red
            Remove-Item -Path $tempFile -Force
            Read-Host "按Enter退出"
            exit 1
        }

        Write-Host "文件下载完成，准备替换..." -ForegroundColor Green

        # 备份现有的Planet文件(如果存在)
        if (Test-Path $planetFile) {
            $backupFile = "$planetFile.bak-$timestamp"
            try {
                Copy-Item -Path $planetFile -Destination $backupFile -Force
                Write-Host "已备份现有Planet文件到: $backupFile" -ForegroundColor Green
            }
            catch {
                Write-Host "备份文件失败，但将继续执行: $_" -ForegroundColor Yellow
            }
        }

        # 停止可能正在运行的ZeroTier进程
        $processes = Get-Process -Name "zerotier-one*", "ZeroTier One" -ErrorAction SilentlyContinue
        if ($processes) {
            Write-Host "正在停止ZeroTier进程..." -ForegroundColor Yellow
            $processes | ForEach-Object {
                try {
                    $_.Kill()
                    $_.WaitForExit(5000)
                }
                catch {
                    Write-Host "无法关闭进程: $_" -ForegroundColor Red
                }
            }
        }

        # 替换Planet文件
        try {
            Copy-Item -Path $tempFile -Destination $planetFile -Force
            Write-Host "Planet文件已成功替换!" -ForegroundColor Green
        }
        catch {
            Write-Host "替换Planet文件失败: $_" -ForegroundColor Red
            Read-Host "按Enter退出"
            exit 1
        }
        finally {
            # 清理临时文件
            if (Test-Path $tempFile) {
                Remove-Item -Path $tempFile -Force
            }
        }

        Write-Host @"

Planet文件已成功替换!
如需启动ZeroTier，请运行根目录下的 start.ps1 脚本。
"@ -ForegroundColor Green
    }

    "2" { # 使用本地文件
        $localFile = Read-Host "请输入本地Planet文件的完整路径"

        if (-not (Test-Path $localFile)) {
            Write-Host "错误: 文件不存在: $localFile" -ForegroundColor Red
            Read-Host "按Enter退出"
            exit 1
        }

        if ((Get-Item $localFile).Length -eq 0) {
            Write-Host "错误: 文件为空: $localFile" -ForegroundColor Red
            Read-Host "按Enter退出"
            exit 1
        }

        # 生成时间戳
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

        # 备份现有的Planet文件(如果存在)
        if (Test-Path $planetFile) {
            $backupFile = "$planetFile.bak-$timestamp"
            try {
                Copy-Item -Path $planetFile -Destination $backupFile -Force
                Write-Host "已备份现有Planet文件到: $backupFile" -ForegroundColor Green
            }
            catch {
                Write-Host "备份文件失败，但将继续执行: $_" -ForegroundColor Yellow
            }
        }

        # 停止可能正在运行的ZeroTier进程
        $processes = Get-Process -Name "zerotier-one*", "ZeroTier One" -ErrorAction SilentlyContinue
        if ($processes) {
            Write-Host "正在停止ZeroTier进程..." -ForegroundColor Yellow
            $processes | ForEach-Object {
                try {
                    $_.Kill()
                    $_.WaitForExit(5000)
                }
                catch {
                    Write-Host "无法关闭进程: $_" -ForegroundColor Red
                }
            }
        }

        # 替换Planet文件
        try {
            Copy-Item -Path $localFile -Destination $planetFile -Force
            Write-Host "Planet文件已成功替换!" -ForegroundColor Green
        }
        catch {
            Write-Host "替换Planet文件失败: $_" -ForegroundColor Red
            Read-Host "按Enter退出"
            exit 1
        }

        Write-Host @"

Planet文件已成功替换!
如需启动ZeroTier，请运行根目录下的 start.ps1 脚本。
"@ -ForegroundColor Green
    }

    "3" { # 查看当前Planet信息
        Show-PlanetInfo
    }

    "4" { # 恢复默认Planet
        Restore-DefaultPlanet
    }

    "5" { # 退出
        Write-Host "退出程序" -ForegroundColor Yellow
        exit 0
    }

    default {
        Write-Host "无效选择，请重新运行脚本" -ForegroundColor Red
    }
}

Read-Host "`n按Enter退出"