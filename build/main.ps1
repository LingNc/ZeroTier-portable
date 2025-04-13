# ZeroTier便携版启动脚本
# 此脚本用于启动便携版ZeroTier
# 作者: LingNc
# 版本: 1.2.2
# 日期: 2025-04-13


# 参数定义 - 必须在脚本开头定义
param (
    [switch]$help = $false,
    [switch]$h = $false,
    [switch]$debug = $false,    # 调试模式开关
    [switch]$logOnly = $false   # 仅记录日志但不显示详细输出
    )

# 全局版本变量 - 便于统一管理版本号
$script:ZT_VERSION="1.2.2"

# BEGIN EMBEDDED FILES
# 此代码段包含直接嵌入到脚本中的文件，使用Base64编码
$script:embeddedFiles = @{
    # 此处将在构建时由build.ps1自动插入直接嵌入的文件
    # 格式: "相对路径" = "Base64内容"
}
# END EMBEDDED FILES

# BEGIN EMBEDDED ZIP PACKAGE
# 此代码段包含嵌入的压缩的ZIP base64编码文件包
# 此处将在构建过程中自动插入由build.ps1生成的代码

$script:packageBase64 = @'
# 这里将由build.ps1在构建时自动插入压缩的数据
'@

function Extract-Package {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DestinationPath
    )

    Write-ZTLog "正在解压文件到 $DestinationPath..." -Level Info -ForegroundColor Yellow

    # 确保目标目录存在
    if (-not (Test-Path $DestinationPath -PathType Container)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
    }

    try {
        # 处理压缩包
        if (-not [string]::IsNullOrEmpty($script:packageBase64) -and -not ($script:packageBase64 -match "^#")) {
            # 解码Base64数据
            $bytes = [Convert]::FromBase64String($script:packageBase64)
            $tempZipFile = Join-Path $env:TEMP "zerotier_package.zip"

            try {
                # 保存ZIP文件
                [System.IO.File]::WriteAllBytes($tempZipFile, $bytes)

                # 解压ZIP文件
                # 首先解压到临时目录，然后移动文件到正确的位置
                $tempExtractPath = Join-Path $env:TEMP "zerotier_extract_$(Get-Random)"
                New-Item -Path $tempExtractPath -ItemType Directory -Force | Out-Null

                try {
                    # 解压文件
                    Expand-Archive -Path $tempZipFile -DestinationPath $tempExtractPath -Force

                    # 获取根文件夹名称（通常是zerotier-portable）
                    $rootFolder = Get-ChildItem -Path $tempExtractPath | Select-Object -First 1

                    if ($rootFolder) {
                        # 移动内容到目标目录
                        Get-ChildItem -Path $rootFolder.FullName | ForEach-Object {
                            $targetPath = Join-Path $DestinationPath $_.Name
                            if (Test-Path $targetPath) {
                                Remove-Item -Path $targetPath -Recurse -Force
                            }
                            Move-Item -Path $_.FullName -Destination $DestinationPath -Force
                        }
                    }

                    Write-ZTLog "压缩包解压完成" -Level Info -ForegroundColor Green
                }
                finally {
                    # 清理临时解压目录
                    if (Test-Path $tempExtractPath) {
                        Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            finally {
                # 清理临时ZIP文件
                if (Test-Path $tempZipFile) {
                    Remove-Item $tempZipFile -Force -ErrorAction SilentlyContinue
                }
            }
        }

        # 处理直接嵌入的文件
        if ($script:embeddedFiles.Count -gt 0) {
            Write-ZTLog "正在提取直接嵌入的文件..." -Level Info -ForegroundColor Yellow
            foreach ($relativePath in $script:embeddedFiles.Keys) {
                try {
                    $targetPath = Join-Path $DestinationPath $relativePath
                    $targetDir = Split-Path -Parent $targetPath

                    # 确保目标目录存在
                    if (-not (Test-Path $targetDir)) {
                        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                    }

                    # 解码并写入文件
                    $bytes = [Convert]::FromBase64String($script:embeddedFiles[$relativePath])
                    [System.IO.File]::WriteAllBytes($targetPath, $bytes)
                    Write-ZTLog "已提取: $relativePath" -Level Info -ForegroundColor Green
                }
                catch {
                    Write-ZTLog "提取文件失败 $relativePath`: $_" -Level Error -ForegroundColor Red
                }
            }
        }

        return $true
    }
    catch {
        Write-ZTLog "解压文件失败: $_" -Level Error -ForegroundColor Red
        return $false
    }
}
# END EMBEDDED ZIP PACKAGE

# 定义日志函数 - 支持日志文件写入和控制台显示
function Write-ZTLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White,
        [switch]$NoDisplay = $false
    )

    # 生成日志条目（带时间戳和等级）
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # 写入日志文件
    if ($script:logFile) {
        Add-Content -Path $script:logFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    }

    # 控制台显示（根据调试模式和NoDisplay决定显示方式）
    if (-not $NoDisplay) {
        if ($debug) {
            # 调试模式下显示完整日志格式
            Write-Host $logEntry -ForegroundColor $ForegroundColor
        } else {
            # 普通模式下仅显示消息
            Write-Host $Message -ForegroundColor $ForegroundColor
        }
    }
}

# 定义纯界面显示函数 - 仅用于界面显示，不写日志
function Write-ZTDisplay {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )

    # 直接显示到控制台，无需时间戳和级别
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# 如果启用了调试模式，调整PowerShell偏好设置
if ($debug) {
    $VerbosePreference = "Continue"
    $DebugPreference = "Continue"
    $ErrorActionPreference = "Inquire"

    # 调试模式暂停函数
    function Debug-Pause {
        param([string]$Message = "按任意键继续...")
        Write-ZTLog "调试暂停: $Message" -Level Debug
        Write-Host $Message -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }

    Write-ZTLog "调试模式已启用 - 日志级别: 详细" -Level Debug
} else {
    $VerbosePreference = "SilentlyContinue"
    $DebugPreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue"
}

# 定义错误处理函数 - 捕获所有空路径错误
function Test-PathSafely {
    param(
        [string]$Path,
        [string]$Type = "文件",
        [switch]$CreateIfDirectory = $false
    )

    if ([string]::IsNullOrEmpty($Path)) {
        Write-ZTLog "警告: 路径参数为空" -Level Warning
        return $false
    }

    try {
        if (Test-Path -Path $Path -ErrorAction Stop) {
            Write-ZTLog "路径检查通过: $Path" -Level Debug
            return $true
        }
        elseif ($CreateIfDirectory -and $Type -eq "目录") {
            Write-ZTLog "创建目录: $Path" -Level Info
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            return $true
        }
        else {
            Write-ZTLog "警告: $Type 不存在 - $Path" -Level Warning
            return $false
        }
    }
    catch {
        Write-ZTLog "错误: 检查路径时发生异常: $Path - $_" -Level Error
        return $false
    }
}

# 确定脚本运行模式和路径
$execMode = "未知"
$exePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
if ($exePath -like "*.exe") {
    # 从EXE运行时，使用临时目录作为程序运行目录
    $execMode = "EXE模式"
    $runtimePath = Join-Path $env:TEMP "ZeroTier-portable-temp"
    # 获取EXE所在目录，数据目录将存放在这里
    $baseDir = Split-Path -Parent $exePath
} else {
    # 直接运行PS1时
    $execMode = "PS1模式"
    $runtimePath = $PSScriptRoot
    $baseDir = $PSScriptRoot
}

# 定义数据目录（在程序目录下而非隐藏文件夹）
$dataPath = Join-Path -Path $baseDir -ChildPath "ZeroTierData"

# 输出运行模式和目录信息
Write-ZTLog "检测到运行模式: $execMode" -Level Info -ForegroundColor Cyan
Write-ZTLog "基础目录: $baseDir" -Level Debug
Write-ZTLog "运行时目录: $runtimePath" -Level Debug
Write-ZTLog "数据目录: $dataPath" -Level Debug

# 在定义路径变量时，就先定义好tap driver路径
$tapDriverPath = Join-Path -Path $runtimePath -ChildPath "bin\tap-driver"

# 检查和清理临时目录
$ztTempPath = Join-Path $env:TEMP "ZeroTier-portable-temp"
if (Test-Path $ztTempPath) {
    Write-ZTLog "发现已存在的ZeroTier临时目录: $ztTempPath" -Level Warning -ForegroundColor Yellow
    try {
        Stop-Process -Name "zerotier-one_x64" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Remove-Item $ztTempPath -Recurse -Force -ErrorAction Stop
        Write-ZTLog "已清理旧的临时目录" -Level Info -ForegroundColor Green
    }
    catch {
        Write-ZTLog "清理临时目录失败: $_" -Level Error -ForegroundColor Red
        Write-ZTLog "请手动删除目录: $ztTempPath" -Level Error -ForegroundColor Red
        exit 1
    }
}

# 确保runtimePath存在
try {
    if (-not (Test-Path $runtimePath)) {
        New-Item -ItemType Directory -Path $runtimePath -Force | Out-Null
        Write-ZTLog "已创建运行时目录: $runtimePath" -Level Info -ForegroundColor Green
    }
}
catch {
    Write-ZTLog "创建运行时目录失败: $_" -Level Error -ForegroundColor Red
    exit 1
}

# 如果是EXE模式且临时目录存在，先删除
if ($execMode -eq "EXE模式" -and (Test-Path $runtimePath)) {
    Write-ZTLog "清理已存在的临时目录..." -Level Info -ForegroundColor Yellow
    Remove-Item $runtimePath -Recurse -Force -ErrorAction SilentlyContinue
}

# 定义清理函数
function Clean-Environment {
    param(
        [string]$systemCmdPath = "C:\Windows\System32",
        [string]$tempPath = $runtimePath
    )

    Write-ZTLog "正在清理环境..." -Level Info -ForegroundColor Yellow

    # 1. 移除命令行工具符号链接或文件
    $cliLink = Join-Path $systemCmdPath "zerotier-cli.bat"
    $idtoolLink = Join-Path $systemCmdPath "zerotier-idtool.bat"

    if (Test-PathSafely -Path $cliLink) {
        Remove-Item $cliLink -Force -ErrorAction SilentlyContinue
        Write-ZTLog "已移除命令行工具 zerotier-cli" -Level Info -ForegroundColor Green
    }

    if (Test-PathSafely -Path $idtoolLink) {
        Remove-Item $idtoolLink -Force -ErrorAction SilentlyContinue
        Write-ZTLog "已移除命令行工具 zerotier-idtool" -Level Info -ForegroundColor Green
    }

    # 2. 清理临时运行目录
    if ($tempPath -ne $PSScriptRoot -and (Test-PathSafely -Path $tempPath)) {
        try {
            Remove-Item $tempPath -Recurse -Force -ErrorAction Stop
            Write-ZTLog "已清理临时文件 $tempPath" -Level Info -ForegroundColor Green
        }
        catch {
            Write-ZTLog "警告: 清理临时目录失败: $_" -Level Warning
            Write-ZTLog "一些临时文件可能保留在: $tempPath" -Level Warning
        }
    }

    Write-ZTLog "环境清理完成" -Level Info -ForegroundColor Green
}

# 注册退出事件处理器
try {
    $exitEvent = {
        param($sender, $eventArgs)
        Write-ZTLog "程序即将退出，正在执行清理..." -Level Info
        Clean-Environment -systemCmdPath "C:\Windows\System32" -tempPath $runtimePath
        Write-ZTLog "程序退出完成" -Level Info
    }
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $exitEvent -ErrorAction SilentlyContinue | Out-Null
}
catch {
    Write-ZTLog "注册退出事件处理失败: $_，程序退出时可能无法自动清理环境" -Level Warning
}

# 检查管理员权限并自动提升
# 获取当前进程信息
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 如果没有管理员权限，则使用提升的方式重新启动
if (-not $isAdmin) {
    # 创建一个启动对象
    $psi = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""

    # 添加调试参数
    if ($debug) { $arguments += " -debug" }
    if ($logOnly) { $arguments += " -logOnly" }

    # 添加其他参数
    if ($args.Count -gt 0) { $arguments += " " + ($args -join " ") }

    $psi.Arguments = $arguments
    $psi.Verb = "runas"  # 请求提升权限
    $psi.WorkingDirectory = Get-Location
    $psi.WindowStyle = 'Normal'  # 使用正常窗口

    # 启动进程
    try {
        Write-ZTLog "需要管理员权限运行此脚本，正在请求权限..." -Level Info -ForegroundColor Yellow
        $p = [System.Diagnostics.Process]::Start($psi)
        # 立即退出当前进程，避免显示两个窗口
        exit
    }
    catch {
        Write-ZTLog "获取管理员权限失败: $_" -Level Error
        Read-Host "按Enter退出"
        exit 1
    }
}

# 版本
$version=$script:ZT_VERSION

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
    start.ps1 [-help|-h] [-debug] [-logOnly]

参数:
    -help, -h    显示此帮助信息
    -debug       启用调试模式，显示详细日志
    -logOnly     仅记录日志到文件，减少控制台输出

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

日志位置:
    $($script:logFile)

"@
    exit 0
}

# 检查是否显示帮助
if ($help -or $h) {
    Show-Help
}

# 显示管理员权限提示
Write-ZTLog "以管理员权限运行..." -Level Info -ForegroundColor Green

# 更新启动界面显示
Write-ZTDisplay @"
===================================================
         ZeroTier 便携版启动脚本
         版本: $version
         日期: 2025-04-13
===================================================
"@ -ForegroundColor Cyan

# 准备运行环境 - 如果从EXE运行，则解压文件到临时目录
if ($runtimePath -ne $PSScriptRoot) {
    Write-ZTLog "准备运行环境..." -Level Info -ForegroundColor Yellow

    # 创建新的临时目录
    if (Test-PathSafely -Path $runtimePath) {
        Remove-Item $runtimePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-ZTLog "已清理旧的临时目录" -Level Info -ForegroundColor Yellow
    }

    # 创建目录结构
    New-Item -ItemType Directory -Path $runtimePath -Force -ErrorAction SilentlyContinue | Out-Null

    # 解压文件到临时目录
    $extractResult = Extract-Package -DestinationPath $runtimePath
    if (-not $extractResult) {
        Write-ZTLog "无法解压或复制运行所需的文件，程序可能无法正常运行" -Level Error -ForegroundColor Red
        $continueAnyway = Read-Host "是否继续尝试运行? (Y/N) [默认: N]"
        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-ZTLog "操作已取消" -Level Error -ForegroundColor Red
            exit 1
        }
    }

    Write-ZTLog "运行环境准备完成" -Level Info -ForegroundColor Green
}

# 初始化日志文件
# 初始化日志路径
$script:logDir = Join-Path -Path $dataPath -ChildPath "logs"
$script:logFile = Join-Path -Path $script:logDir -ChildPath "zerotier-portable-$(Get-Date -Format 'yyyyMMdd').log"

# 如果数据目录不存在，创建普通文件夹（不设置隐藏）
if (-not (Test-PathSafely -Path $dataPath -Type "目录" -CreateIfDirectory)) {
    # 安全性检查 - 目录创建失败的情况
    Write-ZTLog "无法在程序目录创建数据目录: $dataPath" -Level Error -ForegroundColor Red
    Read-Host "按Enter退出"
    exit 1
}
else {
    Write-ZTLog "已创建数据存储目录: $dataPath" -Level Info -ForegroundColor Green

    # 确保日志目录存在
    if (-not (Test-Path -Path $script:logDir -PathType Container)) {
        New-Item -Path $script:logDir -ItemType Directory -Force | Out-Null
        Write-ZTLog "创建日志目录: $($script:logDir)" -Level Info
    }
}

# 确保networks.d子目录存在
$networksDir = Join-Path -Path $dataPath -ChildPath "networks.d"
if (-not (Test-PathSafely -Path $networksDir -Type "目录" -CreateIfDirectory)) {
    Write-ZTLog "无法创建networks.d子目录" -Level Warning
}

# 在data目录初始化后，确保TAP驱动文件存在
$tapDriverFiles = @(
    @{
        Source = Join-Path $tapDriverPath "zttap300.cat"
        Dest = Join-Path $dataPath "zttap300.cat"
    },
    @{
        Source = Join-Path $tapDriverPath "zttap300.inf"
        Dest = Join-Path $dataPath "zttap300.inf"
    },
    @{
        Source = Join-Path $tapDriverPath "zttap300.sys"
        Dest = Join-Path $dataPath "zttap300.sys"
    }
)

Write-ZTLog "验证TAP驱动文件..." -Level Info -ForegroundColor Yellow

# 首先验证源文件是否存在
foreach ($file in $tapDriverFiles) {
    if (-not (Test-Path $file.Source)) {
        Write-ZTLog "错误：源驱动文件不存在: $($file.Source)" -Level Error -ForegroundColor Red
        continue
    }

    if (-not (Test-Path $file.Dest)) {
        Write-ZTLog "复制驱动文件: $($file.Source) -> $($file.Dest)" -Level Info -ForegroundColor Yellow
        try {
            Copy-Item -Path $file.Source -Destination $file.Dest -Force
            if (Test-Path $file.Dest) {
                Write-ZTLog "驱动文件复制成功: $($file.Source)" -Level Info -ForegroundColor Green
            } else {
                throw "复制成功但目标文件不存在"
            }
        }
        catch {
            Write-ZTLog "复制驱动文件失败: $_" -Level Error -ForegroundColor Red
            Write-ZTLog "源文件: $($file.Source)" -Level Error -ForegroundColor Red
            Write-ZTLog "目标文件: $($file.Dest)" -Level Error -ForegroundColor Red
            Write-ZTLog "ZeroTier可能无法正常工作。" -Level Error -ForegroundColor Red

            $continueAnyway = Read-Host "是否继续? (Y/N)"
            if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
                exit 1
            }
        }
    }
    else {
        Write-ZTLog "驱动文件已存在: $($file.Dest)" -Level Debug -ForegroundColor Gray
    }
}

# 更新路径变量以使用新的目录结构
$binPath = Join-Path -Path $runtimePath -ChildPath "bin"
$psPath = Join-Path -Path $runtimePath -ChildPath "ps"
$zerotierExe = Join-Path -Path $binPath -ChildPath "zerotier-one_x64.exe"
$cliBat = Join-Path -Path $binPath -ChildPath "zerotier-cli.bat"
$idtoolBat = Join-Path -Path $binPath -ChildPath "zerotier-idtool.bat"
$createIdentityPs1 = Join-Path -Path $psPath -ChildPath "create-identity.ps1"
$planetReplacePs1 = Join-Path -Path $psPath -ChildPath "planet-replace.ps1"

# 验证关键组件是否可用
$criticalComponents = @{
    "ZeroTier主程序" = $zerotierExe
    "命令行工具" = $cliBat
    "身份工具" = $idtoolBat
}

$missingComponents = $false
foreach ($component in $criticalComponents.GetEnumerator()) {
    if (-not (Test-PathSafely -Path $component.Value)) {
        Write-ZTLog "错误: 无法找到关键组件 $($component.Key): $($component.Value)" -Level Error -ForegroundColor Red
        $missingComponents = $true
    }
    else {
        Write-ZTLog "✅ 已找到组件: $($component.Key)" -Level Info -ForegroundColor Green
    }
}

# 如果关键组件缺失，提供详细诊断信息
if ($missingComponents) {
    Write-ZTLog "`n诊断信息:" -Level Warning
    Write-ZTLog "运行模式: $execMode" -Level Warning
    Write-ZTLog "基础目录: $baseDir" -Level Warning
    Write-ZTLog "运行时目录: $runtimePath" -Level Warning
    Write-ZTLog "数据目录: $dataPath" -Level Warning

    if ($execMode -eq "EXE模式") {
        Write-ZTLog "`nEXE模式下可能的问题:" -Level Warning
        Write-ZTLog "1. 打包过程中未正确包含依赖文件" -Level Warning
        Write-ZTLog "2. 资源提取到临时目录失败" -Level Warning
        Write-ZTLog "3. 临时目录访问权限不足" -Level Warning

        Write-ZTLog "`n请尝试以下解决方案:" -Level Warning
        Write-ZTLog "1. 使用管理员权限运行此EXE" -Level Warning
        Write-ZTLog "2. 检查杀毒软件是否阻止了文件解压" -Level Warning
        Write-ZTLog "3. 尝试重新打包程序，确保包含所有依赖文件" -Level Warning
    }

    Write-ZTLog "`n请确保文件结构完整，必要的文件都在正确的位置。" -Level Error -ForegroundColor Red
    Read-Host "按Enter退出"
    exit 1
}

# 检查身份文件是否存在
$identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
$identityPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public"
$isNewIdentity = $false

# 添加候选界面，让用户选择后续操作
Clear-Host
Write-ZTLog @"
===================================================
      ZeroTier 便携版安装管理
      版本: $version
      日期: 2025-04-10
===================================================

"@ -Level Info -ForegroundColor Cyan

Write-ZTDisplay "请选择操作:" -ForegroundColor Yellow
Write-ZTDisplay "1. 安装 ZeroTier" -ForegroundColor Green
Write-ZTDisplay "2. 卸载 ZeroTier" -ForegroundColor Yellow
Write-ZTDisplay "3. 退出" -ForegroundColor Red

$installChoice = Read-Host "`n请输入选择 (1-3) [默认:1]"

# 如果用户没有输入，默认选择安装
if ([string]::IsNullOrEmpty($installChoice)) {
    $installChoice = "1"
}

# 根据用户选择执行相应操作
switch ($installChoice) {
    "1" {
        Write-ZTLog "`n准备安装 ZeroTier..." -Level Info -ForegroundColor Green
        # 继续执行安装过程，检查身份文件
        if (-not (Test-Path $identityFile)) {
            $isNewIdentity = $true
            Write-ZTLog "未找到身份文件，需要生成新的身份..." -Level Warning -ForegroundColor Yellow
            Write-ZTLog "按任意键进入身份编辑界面..." -Level Info -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            # 检查create-identity.ps1是否存在
            if (-not (Test-Path $createIdentityPs1)) {
                Write-ZTLog "错误：无法找到身份生成脚本: $createIdentityPs1" -Level Error -ForegroundColor Red
                Write-ZTLog "正在尝试使用内置方法生成身份..." -Level Warning -ForegroundColor Yellow

                # 使用内置方法生成身份
                $createIdCmd = "$zerotierExe -i generate `"$identityFile`""
                try {
                    Invoke-Expression $createIdCmd | Out-Null
                    Write-ZTLog "身份文件已生成: $identityFile" -Level Info -ForegroundColor Green

                    # 显示身份信息
                    if (Test-Path $identityPublicFile) {
                        $nodeId = Get-Content -Path $identityPublicFile -Raw
                        Write-ZTLog "节点ID: $nodeId" -Level Info -ForegroundColor Cyan
                    }
                }
                catch {
                    Write-ZTLog "生成身份文件失败: $_" -Level Error -ForegroundColor Red
                    Read-Host "按Enter退出"
                    exit 1
                }
            }
            else {
                # 启动身份管理脚本
                Write-ZTLog "启动身份管理脚本" -Level Info -ForegroundColor Yellow
                if ($execMode -eq "EXE模式") {
                    Write-ZTLog "以EXE模式启动身份管理脚本" -Level Debug
                    $createIdentityArgs = "-ExecutionPolicy Bypass -File `"$createIdentityPs1`" -fromExe -dataPath `"$dataPath`""
                } else {
                    Write-ZTLog "以PS1模式启动身份管理脚本" -Level Debug
                    $createIdentityArgs = "-ExecutionPolicy Bypass -File `"$createIdentityPs1`""
                }
                Start-Process powershell.exe -ArgumentList $createIdentityArgs -Wait -NoNewWindow

                # 检查是否成功生成身份
                if (Test-Path $identityFile) {
                    Write-ZTLog "身份文件已通过管理脚本成功生成" -Level Info -ForegroundColor Green
                    $publicKeyContent = Get-Content -Path $identityPublicFile -Raw -ErrorAction SilentlyContinue
                    if ($publicKeyContent) {
                        $nodeId = $publicKeyContent.Substring(0, 10)  # 取前10个字符作为节点ID
                        Write-ZTLog "节点ID: $nodeId" -Level Info -ForegroundColor Cyan
                    }
                }
                else {
                    Write-ZTLog "警告：未检测到身份文件生成，请手动确认是否已创建身份" -Level Error -ForegroundColor Red
                    $continue = Read-Host "是否继续安装过程? (Y/N)"
                    if ($continue -ne "Y" -and $continue -ne "y") {
                        Write-ZTLog "操作已取消。" -Level Error -ForegroundColor Red
                        exit 1
                    }
                }
            }
        }
    }
    "2" {
        Write-ZTLog "`n准备卸载 ZeroTier..." -Level Warning -ForegroundColor Yellow

        # 定义系统目标位置
        $systemCmdPath = "C:\Windows\System32"
        $cliSystemPath = "$systemCmdPath\zerotier-cli.bat"
        $idtoolSystemPath = "$systemCmdPath\zerotier-idtool.bat"

        # 定义TAP驱动和服务名称
        $tapDriverName = "zttap300"
        $tapServiceName = "zttap300"

        # 删除符号链接
        try {
            if (Test-Path $cliSystemPath) {
                Write-ZTLog "正在删除系统中的zerotier-cli..." -Level Warning -ForegroundColor Yellow
                Remove-Item -Force $cliSystemPath
                Write-ZTLog "已成功删除zerotier-cli" -Level Info -ForegroundColor Green
            }

            if (Test-Path $idtoolSystemPath) {
                Write-ZTLog "正在删除系统中的zerotier-idtool..." -Level Warning -ForegroundColor Yellow
                Remove-Item -Force $idtoolSystemPath
                Write-ZTLog "已成功删除zerotier-idtool" -Level Info -ForegroundColor Green
            }

            # 停止并删除TAP服务
            Write-ZTLog "正在检查并卸载TAP驱动服务..." -Level Warning -ForegroundColor Yellow
            $service = Get-Service -Name $tapServiceName -ErrorAction SilentlyContinue
            if ($service) {
                Write-ZTLog "找到TAP驱动服务: $tapServiceName，正在停止..." -Level Warning -ForegroundColor Yellow
                try {
                    Stop-Service -Name $tapServiceName -Force -ErrorAction Stop
                    Write-ZTLog "服务已停止，正在删除..." -Level Warning -ForegroundColor Yellow
                    # 使用SC删除服务
                    $scOutput = sc.exe delete $tapServiceName 2>&1
                    if ($LASTEXITCODE -eq 0 -or $scOutput -match "成功") {
                        Write-ZTLog "TAP驱动服务成功删除" -Level Info -ForegroundColor Green
                    } else {
                        Write-ZTLog "警告: TAP驱动服务删除返回未知状态: $LASTEXITCODE" -Level Warning -ForegroundColor Yellow
                        Write-ZTLog "输出: $scOutput" -Level Warning -ForegroundColor Yellow
                    }
                } catch {
                    Write-ZTLog "停止或删除TAP驱动服务失败: $_" -Level Error -ForegroundColor Red
                }
            } else {
                Write-ZTLog "未找到TAP驱动服务" -Level Warning -ForegroundColor Yellow
            }

            # 卸载TAP驱动
            Write-ZTLog "正在检查并卸载TAP驱动文件..." -Level Warning -ForegroundColor Yellow

            # 查找驱动的OEM名称
            $driverInfo = pnputil /enum-drivers | Select-String -Pattern $tapDriverName -SimpleMatch
            if ($driverInfo) {
                # 从驱动信息中提取OEM#名称
                $oemPattern = "oem\d+\.inf"
                $matches = [regex]::Matches($driverInfo, $oemPattern)
                if ($matches.Count -gt 0) {
                    $oemName = $matches[0].Value
                    Write-ZTLog "找到TAP驱动: $oemName，正在卸载..." -Level Warning -ForegroundColor Yellow

                    try {
                        # 使用pnputil删除驱动
                        $uninstallOutput = pnputil /delete-driver $oemName /force 2>&1

                        # 检查卸载结果
                        if ($LASTEXITCODE -eq 0 -or $uninstallOutput -match "成功") {
                            Write-ZTLog "TAP驱动成功卸载" -Level Info -ForegroundColor Green
                        }
                        else {
                            Write-ZTLog "警告: TAP驱动卸载返回未知状态: $LASTEXITCODE" -Level Warning -ForegroundColor Yellow
                            Write-ZTLog "输出: $uninstallOutput" -Level Warning -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-ZTLog "卸载TAP驱动失败: $_" -Level Error -ForegroundColor Red
                    }
                }
                else {
                    Write-ZTLog "警告: 找到TAP驱动但无法确定OEM名称" -Level Warning -ForegroundColor Yellow
                }
            }
            else {
                Write-ZTLog "未找到已安装的TAP驱动" -Level Warning -ForegroundColor Yellow
            }

            Write-ZTLog "`nZeroTier 已成功卸载！" -Level Info -ForegroundColor Green
            Write-ZTLog "卸载操作完成。" -Level Info -ForegroundColor Green
            Read-Host "按Enter退出"
            exit 0
        }
        catch {
            Write-ZTLog "卸载ZeroTier失败: $_" -Level Error -ForegroundColor Red
            Read-Host "按Enter退出"
            exit 1
        }
    }
    "3" {
        Write-ZTLog "`n操作已取消，正在退出..." -Level Warning -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-ZTLog "`n无效选择，默认执行安装操作..." -Level Error -ForegroundColor Red
        Start-Sleep -Seconds 2
        # 继续执行安装流程
    }
}

# 如果是新生成的身份，询问是否替换Planet文件
if ($isNewIdentity) {
    Write-ZTLog "`n检测到新生成的身份，您可能需要配置自定义Planet服务器。" -Level Warning -ForegroundColor Yellow
    $replacePlanet = Read-Host "是否需要配置自定义Planet服务器? (Y/N)"

    if ($replacePlanet -eq "Y" -or $replacePlanet -eq "y") {
        # 检查planet-replace.ps1是否存在
        if (-not (Test-Path $planetReplacePs1)) {
            Write-ZTLog "错误：无法找到Planet替换脚本: $planetReplacePs1" -Level Error -ForegroundColor Red
            Write-ZTLog "将使用默认Planet服务器继续..." -Level Warning -ForegroundColor Yellow
        }
        else {
            # 启动Planet替换脚本
            Write-ZTLog "启动Planet替换脚本" -Level Info -ForegroundColor Yellow
            if ($execMode -eq "EXE模式") {
                Write-ZTLog "以EXE模式启动Planet替换脚本" -Level Debug
                $planetReplaceArgs = "-ExecutionPolicy Bypass -File `"$planetReplacePs1`" -fromExe -dataPath `"$dataPath`""
            } else {
                Write-ZTLog "以PS1模式启动Planet替换脚本" -Level Debug
                $planetReplaceArgs = "-ExecutionPolicy Bypass -File `"$planetReplacePs1`""
            }
            Start-Process powershell.exe -ArgumentList $planetReplaceArgs -Wait -NoNewWindow
            Write-ZTLog "Planet配置已完成，继续启动过程..." -Level Info -ForegroundColor Green
        }
    }
}

# 检查TAP驱动是否已安装
Write-ZTLog "正在检查TAP驱动安装状态..." -Level Info -ForegroundColor Yellow
$tapDriverInf = Join-Path -Path $tapDriverPath -ChildPath "zttap300.inf"
$tapDriverSys = Join-Path -Path $tapDriverPath -ChildPath "zttap300.sys"
$tapDriverCat = Join-Path -Path $tapDriverPath -ChildPath "zttap300.cat"
# 定义驱动程序的服务名称，用于后续卸载
$tapServiceName = "zttap300"

# 检查驱动是否已安装
$tapInstalled = $false
$driverInfo = pnputil /enum-drivers | Select-String -Pattern "zttap300" -SimpleMatch

if ($driverInfo) {
    $tapInstalled = $true
    Write-ZTLog "TAP驱动已安装" -Level Info -ForegroundColor Green
}
else {
    Write-ZTLog "安装TAP驱动..." -Level Info -ForegroundColor Yellow

    # 1. 验证CAT签名
    Write-ZTLog "验证驱动签名..." -Level Info -ForegroundColor Yellow
    try {
        $catSig = Get-AuthenticodeSignature $tapDriverCat
        if ($catSig.Status -eq "Valid") {
            Write-ZTLog "驱动签名验证通过" -Level Info -ForegroundColor Green
        } else {
            Write-ZTLog "警告: 驱动签名无效: $($catSig.StatusMessage)" -Level Warning -ForegroundColor Yellow
            $continueUnsigned = Read-Host "驱动签名无效，是否继续安装? (Y/N)"
            if ($continueUnsigned -ne "Y" -and $continueUnsigned -ne "y") {
                Write-ZTLog "操作已取消。" -Level Error -ForegroundColor Red
                exit 1
            }
        }
    }
    catch {
        Write-ZTLog "警告: 验证驱动签名失败: $_" -Level Warning -ForegroundColor Yellow
    }

    # 2. 使用pnputil安装INF驱动
    try {
        Write-ZTLog "正在安装INF驱动..." -Level Info -ForegroundColor Yellow
        $pnputilOutput = pnputil /add-driver "$tapDriverInf" /install 2>&1
        # 检查输出是否包含成功信息
        if ($LASTEXITCODE -eq 0 -or $pnputilOutput -match "成功") {
            Write-ZTLog "TAP驱动INF安装成功" -Level Info -ForegroundColor Green
            $tapInstalled = $true
        }
        else {
            throw "pnputil返回错误代码: $LASTEXITCODE"
        }
    }
    catch {
        Write-ZTLog "警告: TAP驱动INF安装失败: $_" -Level Error -ForegroundColor Red
        Write-ZTLog "原始输出: $pnputilOutput" -Level Error -ForegroundColor Red
        $continueAnyway = Read-Host "是否继续尝试注册SYS服务? (Y/N)"
        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-ZTLog "操作已取消。" -Level Error -ForegroundColor Red
            exit 1
        }
    }

    # 3. 注册SYS服务
    try {
        Write-ZTLog "正在注册TAP驱动服务..." -Level Info -ForegroundColor Yellow
        # 检查服务是否已存在
        $existingService = Get-Service -Name $tapServiceName -ErrorAction SilentlyContinue

        if (-not $existingService) {
            # 注册新服务
            New-Service -Name $tapServiceName -BinaryPathName $tapDriverSys -DisplayName "ZeroTier TAP Driver" -StartupType Manual
            Write-ZTLog "服务注册成功" -Level Info -ForegroundColor Green
        } else {
            Write-ZTLog "服务已存在，尝试启动服务" -Level Info -ForegroundColor Yellow
        }

        # 尝试启动服务
        Start-Service -Name $tapServiceName
        Write-ZTLog "TAP驱动服务启动成功" -Level Info -ForegroundColor Green
        $tapInstalled = $true
    }
    catch {
        Write-ZTLog "警告: TAP驱动服务注册/启动失败: $_" -Level Error -ForegroundColor Red
        Write-ZTLog "ZeroTier可能无法正常工作，网络连接可能受限。" -Level Error -ForegroundColor Red
        $continueAnyway = Read-Host "是否继续启动ZeroTier? (Y/N)"
        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-ZTLog "操作已取消。" -Level Error -ForegroundColor Red
            exit 1
        }
    }
}

# 添加CLI和IDTool到系统环境（优先创建符号链接，失败则复制文件）
Write-ZTLog "正在添加ZeroTier命令行工具到系统环境..." -Level Info -ForegroundColor Yellow

# 定义系统目标位置
$systemCmdPath = "C:\Windows\System32"
$cliSystemPath = "$systemCmdPath\zerotier-cli.bat"
$idtoolSystemPath = "$systemCmdPath\zerotier-idtool.bat"

try {
    # 首先尝试创建符号链接（需要管理员权限）
    Write-ZTLog "尝试创建命令行工具符号链接..." -Level Info -ForegroundColor Yellow

    # 移除现有文件（如果存在）
    if (Test-Path $cliSystemPath) {
        Remove-Item -Force $cliSystemPath -ErrorAction Stop
    }
    if (Test-Path $idtoolSystemPath) {
        Remove-Item -Force $idtoolSystemPath -ErrorAction Stop
    }

    # 创建符号链接
    $mkLinkCliResult = cmd /c mklink "$cliSystemPath" "$cliBat" 2>&1
    $mkLinkIdtoolResult = cmd /c mklink "$idtoolSystemPath" "$idtoolBat" 2>&1

    # 验证链接创建成功
    if ((Test-Path $cliSystemPath) -and (Test-Path $idtoolSystemPath)) {
        Write-ZTLog "符号链接创建成功!" -Level Info -ForegroundColor Green
    } else {
        throw "符号链接创建失败"
    }
}
catch {
    Write-ZTLog "符号链接创建失败: $_，使用文件复制方式..." -Level Warning -ForegroundColor Yellow

    # 创建或更新zerotier-cli和zerotier-idtool的包装脚本
    # zerotier-cli包装脚本，添加replace参数支持
    $cliContent = @"
@echo off
:: ZeroTier CLI包装器
:: 自动将命令转发到便携版ZeroTier安装位置
:: 版本: 1.0.0

:: 设置数据路径环境变量
SET ZT_HOME=$dataPath
:: 调用实际的zerotier-cli
"$binPath\zerotier-cli.bat" %*
"@

    # zerotier-idtool包装脚本，添加inter参数支持
    $idtoolContent = @"
@echo off
:: ZeroTier IDTool包装器
:: 自动将命令转发到便携版ZeroTier安装位置
:: 版本: 1.0.0

:: 调用实际的zerotier-idtool
"$binPath\zerotier-idtool.bat" %*
"@

    # 使用文件复制方式
    try {
        $cliContent | Out-File -FilePath $cliSystemPath -Encoding ASCII -Force
        $idtoolContent | Out-File -FilePath $idtoolSystemPath -Encoding ASCII -Force
        Write-ZTLog "命令行工具已通过文件复制方式添加到系统路径" -Level Info -ForegroundColor Green
    }
    catch {
        Write-ZTLog "添加命令行工具到系统环境失败: $_" -Level Error -ForegroundColor Red
        $continueAnyway = Read-Host "是否继续运行ZeroTier? (Y/N)"
        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-ZTLog "操作已取消。" -Level Error -ForegroundColor Red
            exit 1
        }
    }
}

Write-ZTLog "命令行工具已配置完成" -Level Info -ForegroundColor Green
Write-ZTLog "您现在可以在任何命令提示符中使用 'zerotier-cli' 和 'zerotier-idtool' 命令。" -Level Info -ForegroundColor Green

# 启动ZeroTier，指定数据目录
$startArgs = @(
    "-C",             # 使用命令行模式而不是服务模式
    "-p9993",         # 指定默认端口
    "`"$dataPath`""   # 指定数据目录
)

# 设置用于捕获Ctrl+C的变量
$global:ctrlCPressed = $false

# 定义Ctrl+C事件处理器
$null = [Console]::CancelKeyPress.Connect({
    param($sender, $e)
    $global:ctrlCPressed = $true
    $e.Cancel = $true  # 阻止立即终止，让我们有机会清理
    Write-ZTLog "`n检测到Ctrl+C，正在准备清理环境..." -Level Warning -ForegroundColor Yellow
})

try {
    # 启动ZeroTier
    $process = Start-Process -FilePath $zerotierExe -ArgumentList $startArgs -PassThru -NoNewWindow
    Write-ZTLog "ZeroTier进程已启动，PID: $($process.Id)" -Level Info -ForegroundColor Green

    # 等待ZeroTier初始化
    Write-ZTLog "等待ZeroTier初始化..." -Level Info -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    # 获取并显示节点状态
    Write-ZTLog "`n正在获取节点状态..." -Level Info -ForegroundColor Yellow
    try {
        $nodeStatus = & "$zerotierExe" -q -D"$dataPath" "info" 2>&1

        # 将结果转换为字符串以确保一致处理
        $nodeStatusStr = $nodeStatus | Out-String
        Write-ZTLog "原始状态: $nodeStatusStr" -Level Debug -ForegroundColor Gray

        # 检查是否有200状态码表示成功
        if ($nodeStatusStr -match "200") {
            Write-ZTLog "ZeroTier服务启动成功" -Level Info -ForegroundColor Green

            # 尝试提取节点ID和状态（如果可用）
            if ($nodeStatusStr -match "200 info (\w+)") {
                $nodeId = $Matches[1]
                Write-ZTLog "节点ID: $nodeId" -Level Info -ForegroundColor Cyan
            }

            # 检查各种可能的状态
            if ($nodeStatusStr -match "ONLINE") {
                Write-ZTLog "节点状态: ONLINE (已连接)" -Level Info -ForegroundColor Green
                Write-ZTLog "节点已成功连接到ZeroTier网络！" -Level Info -ForegroundColor Green
            }
            elseif ($nodeStatusStr -match "TUNNELED") {
                Write-ZTLog "节点状态: TUNNELED (通过隧道连接)" -Level Info -ForegroundColor Green
                Write-ZTLog "节点已成功通过隧道连接到ZeroTier网络！" -Level Info -ForegroundColor Green
            }
            elseif ($nodeStatusStr -match "OFFLINE") {
                Write-ZTLog "节点状态: OFFLINE (离线)" -Level Warning -ForegroundColor Yellow
                Write-ZTLog "节点服务已启动，但尚未连接到网络。" -Level Warning -ForegroundColor Yellow
            }
            else {
                Write-ZTLog "节点状态: 未知" -Level Warning -ForegroundColor Yellow
                Write-ZTLog "节点状态未明确显示，服务已启动但可能需要检查网络设置。" -Level Warning -ForegroundColor Yellow
            }
        }
        else {
            Write-ZTLog "警告: 无法确认ZeroTier服务是否正常启动" -Level Error -ForegroundColor Red
        }

        # 显示已加入的网络，完全重写这部分，避免使用数组索引
        Write-ZTLog "`n已加入的网络：" -Level Info -ForegroundColor Cyan
        try {
            $networks = & "$zerotierExe" -q -D"$dataPath" "listnetworks" 2>&1

            # 转换为字符串便于处理
            $networksStr = $networks | Out-String
            Write-ZTLog "原始网络列表: $networksStr" -Level Debug -ForegroundColor Gray

            # 拆分成行来逐行处理
            $networkLines = $networksStr -split "`n"
            $foundNetwork = $false

            foreach ($line in $networkLines) {
                if ([string]::IsNullOrEmpty($line)) { continue }

                if ($line -match "200 listnetworks\s+([0-9a-f]+)") {
                    $foundNetwork = $true
                    $networkId = $Matches[1]
                    Write-ZTLog "`n- 网络ID: $networkId" -Level Info -ForegroundColor Green

                    # 尝试提取更多信息，但避免使用索引访问
                    if ($line -match "200 listnetworks\s+[0-9a-f]+\s+(\S+)") {
                        $networkName = $Matches[1]
                        Write-ZTLog "  名称: $networkName" -Level Info -ForegroundColor Green
                    }

                    # 查找状态信息
                    if ($line -match "OK|PUBLIC|PRIVATE") {
                        Write-ZTLog "  状态: 已连接" -Level Info -ForegroundColor Green
                    }

                    # 查找IP信息
                    if ($line -match "(\d+\.\d+\.\d+\.\d+/\d+)") {
                        $ip = $Matches[1]
                        Write-ZTLog "  IP地址: $ip" -Level Info -ForegroundColor Green
                    }
                }
            }

            if (-not $foundNetwork) {
                Write-ZTLog "尚未加入任何网络" -Level Warning -ForegroundColor Yellow
            }
        }
        catch {
            Write-ZTLog "获取网络列表失败: $_" -Level Error -ForegroundColor Red
            Write-ZTLog "尚未加入任何网络或网络信息获取失败" -Level Warning -ForegroundColor Yellow
        }
    }
    catch {
        Write-ZTLog "获取节点状态失败: $_" -Level Error -ForegroundColor Red
        Write-ZTLog "无法确定节点状态，请检查ZeroTier服务是否正常启动" -Level Error -ForegroundColor Red
    }
    Start-Sleep -Seconds 4
    Clear-Host
    # 显示使用信息
    Write-ZTLog @"
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
"@ -Level Info -ForegroundColor Cyan

    # 保持脚本运行，直到用户按Ctrl+C或进程终止
    Write-ZTLog "按Ctrl+C停止ZeroTier并退出..." -Level Warning -ForegroundColor Yellow
    while ($true) {
        # 检查是否按下了Ctrl+C
        if ($global:ctrlCPressed) {
            Write-ZTLog "正在处理Ctrl+C请求，准备退出..." -Level Warning -ForegroundColor Yellow
            break
        }

        # 检查ZeroTier进程是否仍在运行
        if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
            Write-ZTLog "ZeroTier进程已终止，正在退出..." -Level Error -ForegroundColor Red
            break
        }

        # 短暂睡眠以减少CPU使用
        Start-Sleep -Milliseconds 500
    }
}
catch {
    Write-ZTLog "ZeroTier运行过程中出错: $_" -Level Error -ForegroundColor Red
}
finally {
    # 清理工作
    Write-ZTLog "正在执行退出清理..." -Level Warning -ForegroundColor Yellow

    # 1. 停止ZeroTier进程
    if ($process -and (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
        Write-ZTLog "正在停止ZeroTier进程..." -Level Warning -ForegroundColor Yellow
        try {
            $process.Kill()
            $process.WaitForExit(5000)
            Write-ZTLog "ZeroTier进程已停止" -Level Info -ForegroundColor Green
        }
        catch {
            Write-ZTLog "停止ZeroTier进程失败: $_" -Level Error -ForegroundColor Red
        }
    }

    # 2. 清理环境
    Clean-Environment -systemCmdPath "C:\Windows\System32" -tempPath $runtimePath

    Write-ZTLog "ZeroTier便携版已完全退出" -Level Info -ForegroundColor Green
    Write-ZTLog "您可以安全地移除U盘了" -Level Info -ForegroundColor Cyan

    # 等待用户确认
    if (-not $global:ctrlCPressed) {
        Read-Host "按Enter退出"
    }
}