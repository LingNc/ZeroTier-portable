# ZeroTier便携版启动脚本
# 此脚本用于启动便携版ZeroTier
# 作者: GitHub Copilot
# 版本: 1.1.1
# 日期: 2025-04-10
# 版本
$version="1.1.1"

# 参数定义
param (
    [switch]$help = $false,
    [switch]$h = $false
)

# 显示帮助信息
function Show-Help {
    Write-Host @"
===================================================
            ZeroTier 便携版 帮助信息
            版本: $version
===================================================

描述:
    该脚本用于启动ZeroTier便携版，自动完成身份检查、TAP驱动安装
    和ZeroTier服务启动过程。

用法:
    start.ps1 [-help|-h]

参数:
    -help, -h    显示此帮助信息

功能:
    1. 检查数据目录并创建必要的子目录
    2. 检查身份文件是否存在，如不存在则生成新身份
    3. 检查并安装TAP驱动
    4. 添加命令行工具到系统环境
    5. 启动ZeroTier服务
    6. 显示节点状态和已加入的网络

注意:
    此脚本需要管理员权限运行

相关命令:
    zerotier-cli          - ZeroTier网络管理工具
    zerotier-cli replace  - 启动Planet文件替换工具
    zerotier-idtool inter - 启动身份管理工具

"@
    exit 0
}

# 检查是否显示帮助
if ($help -or $h) {
    Show-Help
}

#Requires -RunAsAdministrator

# 显示启动标志
Write-Host @"
===================================================
         ZeroTier 便携版启动脚本
         版本: $version
         日期: 2025-04-10
===================================================
"@ -ForegroundColor Cyan

# 获取脚本所在目录
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$binPath = Join-Path -Path $scriptPath -ChildPath "bin"
$dataPath = Join-Path -Path $scriptPath -ChildPath "data"
$psPath = Join-Path -Path $scriptPath -ChildPath "ps"
$zerotierExe = Join-Path -Path $binPath -ChildPath "zerotier-one_x64.exe"
$tapDriverPath = Join-Path -Path $binPath -ChildPath "tap-driver"
$cliBat = Join-Path -Path $binPath -ChildPath "zerotier-cli.bat"
$idtoolBat = Join-Path -Path $binPath -ChildPath "zerotier-idtool.bat"
$createIdentityPs1 = Join-Path -Path $psPath -ChildPath "create-identity.ps1"
$planetReplacePs1 = Join-Path -Path $psPath -ChildPath "planet-replace.ps1"

# 检查组件是否存在
if (-not (Test-Path $zerotierExe)) {
    Write-Host "错误：无法找到ZeroTier可执行文件: $zerotierExe" -ForegroundColor Red
    Write-Host "请确保文件结构完整，bin目录下包含所有必要文件。" -ForegroundColor Red
    Read-Host "按Enter退出"
    exit 1
}

# 确保data目录存在
if (-not (Test-Path $dataPath)) {
    Write-Host "创建数据目录: $dataPath" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null

    # 创建networks.d子目录
    $networksDir = Join-Path -Path $dataPath -ChildPath "networks.d"
    if (-not (Test-Path $networksDir)) {
        New-Item -ItemType Directory -Path $networksDir -Force | Out-Null
    }
}

# 检查身份文件是否存在
$identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
$identityPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public"
$isNewIdentity = $false

if (-not (Test-Path $identityFile)) {
    $isNewIdentity = $true
    Write-Host "未找到身份文件，需要生成新的身份..." -ForegroundColor Yellow

    # 检查create-identity.ps1是否存在
    if (-not (Test-Path $createIdentityPs1)) {
        Write-Host "错误：无法找到身份生成脚本: $createIdentityPs1" -ForegroundColor Red
        Write-Host "正在尝试使用内置方法生成身份..." -ForegroundColor Yellow

        # 使用内置方法生成身份
        $createIdCmd = "$zerotierExe -i generate `"$identityFile`""
        try {
            Invoke-Expression $createIdCmd | Out-Null
            Write-Host "身份文件已生成: $identityFile" -ForegroundColor Green

            # 显示身份信息
            if (Test-Path $identityPublicFile) {
                $nodeId = Get-Content -Path $identityPublicFile -Raw
                Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "生成身份文件失败: $_" -ForegroundColor Red
            Read-Host "按Enter退出"
            exit 1
        }
    }
    else {
        # 使用create-identity.ps1脚本生成身份
        Write-Host "启动身份管理脚本，请按提示操作..." -ForegroundColor Yellow
        Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$createIdentityPs1`" -auto" -Wait -NoNewWindow

        # 检查是否成功生成身份
        if (Test-Path $identityFile) {
            Write-Host "身份文件已通过管理脚本成功生成" -ForegroundColor Green
            $nodeId = Get-Content -Path $identityPublicFile -Raw -ErrorAction SilentlyContinue
            if ($nodeId) {
                Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "警告：未检测到身份文件生成，请手动确认是否已创建身份" -ForegroundColor Red
            $continue = Read-Host "是否继续启动过程? (Y/N)"
            if ($continue -ne "Y" -and $continue -ne "y") {
                Write-Host "操作已取消。" -ForegroundColor Red
                exit 1
            }
        }
    }
}

# 如果是新生成的身份，询问是否替换Planet文件
if ($isNewIdentity) {
    Write-Host "`n检测到新生成的身份，您可能需要配置自定义Planet服务器。" -ForegroundColor Yellow
    $replacePlanet = Read-Host "是否需要配置自定义Planet服务器? (Y/N)"

    if ($replacePlanet -eq "Y" -or $replacePlanet -eq "y") {
        # 检查planet-replace.ps1是否存在
        if (-not (Test-Path $planetReplacePs1)) {
            Write-Host "错误：无法找到Planet替换脚本: $planetReplacePs1" -ForegroundColor Red
            Write-Host "将使用默认Planet服务器继续..." -ForegroundColor Yellow
        }
        else {
            # 启动Planet替换脚本
            Write-Host "启动Planet替换脚本，请按提示操作..." -ForegroundColor Yellow
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$planetReplacePs1`"" -Wait -NoNewWindow
            Write-Host "Planet配置已完成，继续启动过程..." -ForegroundColor Green
        }
    }
}

# 检查TAP驱动是否已安装
Write-Host "正在检查TAP驱动安装状态..." -ForegroundColor Yellow
$tapDriverInf = Join-Path -Path $tapDriverPath -ChildPath "zttap300.inf"
$tapCheckResult = & "$tapDriverPath\tapctl.exe" list 2>&1
$tapInstalled = $false

if ($tapCheckResult -match "Instance") {
    $tapInstalled = $true
    Write-Host "TAP驱动已安装" -ForegroundColor Green
}
else {
    Write-Host "安装TAP驱动..." -ForegroundColor Yellow
    $installResult = & "$tapDriverPath\tapctl.exe" install "$tapDriverInf" tap0901 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "TAP驱动安装成功" -ForegroundColor Green
        $tapInstalled = $true
    }
    else {
        Write-Host "警告: TAP驱动安装失败: $installResult" -ForegroundColor Red
        Write-Host "ZeroTier可能无法正常工作，网络连接可能受限。" -ForegroundColor Red
        $continueAnyway = Read-Host "是否继续启动ZeroTier? (Y/N)"

        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-Host "操作已取消。" -ForegroundColor Red
            exit 1
        }
    }
}

# 添加CLI和IDTool到系统环境（创建符号链接）
Write-Host "正在添加ZeroTier命令行工具到系统环境..." -ForegroundColor Yellow

# 定义系统目标位置
$systemCmdPath = "C:\Windows\System32"
$cliSystemPath = "$systemCmdPath\zerotier-cli.bat"
$idtoolSystemPath = "$systemCmdPath\zerotier-idtool.bat"

# 创建或更新zerotier-cli和zerotier-idtool的包装脚本
# zerotier-cli包装脚本，添加replace参数支持
$cliContent = @"
@echo off
:: ZeroTier CLI包装器
:: 自动将命令转发到便携版ZeroTier安装位置
:: 版本: 1.0.0

:: 正常调用zerotier-cli
SET ZT_HOME=$dataPath
"$binPath\zerotier-cli.bat" %*
"@

# zerotier-idtool包装脚本，添加inter参数支持
$idtoolContent = @"
@echo off
:: ZeroTier IDTool包装器
:: 自动将命令转发到便携版ZeroTier安装位置
:: 版本: 1.0.0

:: 正常调用zerotier-idtool
"$binPath\zerotier-idtool.bat" %*
"@

# 检查并创建或更新系统链接
try {
    if (Test-Path $cliSystemPath) {
        Write-Host "更新系统中的zerotier-cli..." -ForegroundColor Yellow
        Remove-Item -Force $cliSystemPath
    } else {
        Write-Host "创建系统中的zerotier-cli..." -ForegroundColor Yellow
    }
    $cliContent | Out-File -FilePath $cliSystemPath -Encoding ASCII

    if (Test-Path $idtoolSystemPath) {
        Write-Host "更新系统中的zerotier-idtool..." -ForegroundColor Yellow
        Remove-Item -Force $idtoolSystemPath
    } else {
        Write-Host "创建系统中的zerotier-idtool..." -ForegroundColor Yellow
    }
    $idtoolContent | Out-File -FilePath $idtoolSystemPath -Encoding ASCII

    Write-Host "命令行工具已成功添加到系统路径！" -ForegroundColor Green
    Write-Host "您现在可以在任何命令提示符中使用 'zerotier-cli' 和 'zerotier-idtool' 命令。" -ForegroundColor Green
}
catch {
    Write-Host "添加命令行工具到系统环境失败: $_" -ForegroundColor Red
}

# 启动ZeroTier
Write-Host "正在启动ZeroTier..." -ForegroundColor Yellow

# 检查是否有其他ZeroTier实例正在运行
$processes = Get-Process -Name "zerotier-one*", "ZeroTier One" -ErrorAction SilentlyContinue

if ($processes) {
    Write-Host "检测到有ZeroTier实例正在运行，正在关闭..." -ForegroundColor Yellow
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

# 启动ZeroTier，指定数据目录
$startArgs = @(
    "-C",             # 使用命令行模式而不是服务模式
    "-p9993",         # 指定默认端口
    "`"$dataPath`""   # 指定数据目录
)

try {
    $process = Start-Process -FilePath $zerotierExe -ArgumentList $startArgs -PassThru -NoNewWindow
    Write-Host "ZeroTier进程已启动，PID: $($process.Id)" -ForegroundColor Green

    # 等待ZeroTier初始化
    Write-Host "等待ZeroTier初始化..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    # 获取并显示节点状态
    Write-Host "`n正在获取节点状态..." -ForegroundColor Yellow
    $nodeStatus = & "$zerotierExe" -q -D"$dataPath" "info" 2>&1

    if ($nodeStatus -match "\d{10}") {
        Write-Host "节点已运行，ID: $nodeStatus" -ForegroundColor Green

        # 显示已加入的网络
        Write-Host "`n已加入的网络：" -ForegroundColor Cyan
        $networks = & "$zerotierExe" -q -D"$dataPath" "listnetworks" 2>&1

        if ($networks -match "OK") {
            $networksFormatted = $networks -replace "^200 listnetworks ", "" | ForEach-Object { $_ -split " " | Select-Object -First 1 }
            foreach ($network in $networksFormatted) {
                if ($network -match "^[0-9a-f]{16}$") {
                    Write-Host "- $network" -ForegroundColor Green
                }
            }
        }
        else {
            Write-Host "尚未加入任何网络" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "警告: 无法获取节点状态，节点可能未正确启动" -ForegroundColor Red
        Write-Host "原始输出: $nodeStatus" -ForegroundColor Red
    }

    # 显示使用信息
    Write-Host @"

===================================================
ZeroTier便携版已启动！

要加入网络，请运行:
   zerotier-cli join <网络ID>

要查看网络状态:
   zerotier-cli listnetworks

要查看节点信息:
   zerotier-cli info

要替换Planet文件:
   zerotier-cli replace

要管理身份:
   zerotier-idtool inter

要停止ZeroTier:
   关闭此PowerShell窗口或按Ctrl+C
===================================================
"@ -ForegroundColor Cyan

    # 保持脚本运行，直到用户按Ctrl+C
    try {
        Write-Host "按Ctrl+C停止ZeroTier并退出..." -ForegroundColor Yellow
        while ($true) {
            Start-Sleep -Seconds 60

            # 检查ZeroTier进程是否仍在运行
            if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
                # 进程仍在运行，继续等待
            }
            else {
                Write-Host "ZeroTier进程已终止，正在退出..." -ForegroundColor Red
                break
            }
        }
    }
    finally {
        # 确保在脚本结束时关闭ZeroTier
        if (Get-Process -Id $process.Id -ErrorAction SilentlyContinue) {
            $process.Kill()
            Write-Host "ZeroTier已停止。" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "启动ZeroTier失败: $_" -ForegroundColor Red
    Read-Host "按Enter退出"
    exit 1
}