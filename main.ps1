# ZeroTier便携版启动脚本
# 此脚本用于启动便携版ZeroTier
# 作者: LingNc
# 版本: 1.2.0
# 日期: 2025-04-10

# 参数定义 - 必须在脚本开头定义
param (
    [switch]$help = $false,
    [switch]$h = $false
)

# 定义错误处理函数 - 捕获所有空路径错误
function Test-PathSafely {
    param(
        [string]$Path,
        [string]$Type = "文件",
        [switch]$CreateIfDirectory = $false
    )

    if ([string]::IsNullOrEmpty($Path)) {
        Write-Host "警告: 路径参数为空" -ForegroundColor Yellow
        return $false
    }

    try {
        if (Test-Path -Path $Path -ErrorAction Stop) {
            return $true
        }
        elseif ($CreateIfDirectory -and $Type -eq "目录") {
            Write-Host "创建目录: $Path" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            return $true
        }
        else {
            Write-Host "警告: $Type 不存在 - $Path" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "错误: 检查路径时发生异常: $Path - $_" -ForegroundColor Red
        return $false
    }
}

# 确定脚本运行模式和路径
$execMode = "未知"
if ($null -ne $MyInvocation.MyCommand.Module) {
    # 从EXE运行时，使用临时目录作为运行时目录
    $execMode = "EXE模式"
    $runtimePath = Join-Path $env:TEMP "ZeroTier-Portable-Temp"
    # 获取EXE所在目录作为基础目录
    $baseDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
} else {
    # 直接运行PS1时
    $execMode = "PS1模式"
    $runtimePath = $PSScriptRoot
    $baseDir = $PSScriptRoot
}

# 输出运行模式和目录信息
Write-Host "检测到运行模式: $execMode" -ForegroundColor Cyan
Write-Host "基础目录: $baseDir" -ForegroundColor Cyan
Write-Host "运行时目录: $runtimePath" -ForegroundColor Cyan

# 定义清理函数
function Clean-Environment {
    param(
        [string]$systemCmdPath = "C:\Windows\System32",
        [string]$tempPath = $runtimePath
    )

    Write-Host "正在清理环境..." -ForegroundColor Yellow

    # 1. 移除命令行工具符号链接或文件
    $cliLink = Join-Path $systemCmdPath "zerotier-cli.bat"
    $idtoolLink = Join-Path $systemCmdPath "zerotier-idtool.bat"

    if (Test-PathSafely -Path $cliLink) {
        Remove-Item $cliLink -Force -ErrorAction SilentlyContinue
        Write-Host "已移除命令行工具 zerotier-cli" -ForegroundColor Green
    }

    if (Test-PathSafely -Path $idtoolLink) {
        Remove-Item $idtoolLink -Force -ErrorAction SilentlyContinue
        Write-Host "已移除命令行工具 zerotier-idtool" -ForegroundColor Green
    }

    # 2. 清理临时运行目录
    if ($tempPath -ne $PSScriptRoot -and (Test-PathSafely -Path $tempPath)) {
        Remove-Item $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "已清理临时文件 $tempPath" -ForegroundColor Green
    }

    Write-Host "环境清理完成" -ForegroundColor Green
}

# 注册退出事件处理器
try {
    $exitEvent = {
        param($sender, $eventArgs)
        Clean-Environment -systemCmdPath "C:\Windows\System32" -tempPath $runtimePath
    }
    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $exitEvent -ErrorAction SilentlyContinue | Out-Null
}
catch {
    Write-Host "注册退出事件处理失败: $_，程序退出时可能无法自动清理环境" -ForegroundColor Yellow
}

# 检查管理员权限并自动提升
# 获取当前进程信息
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 如果没有管理员权限，则使用提升的方式重新启动
if (-not $isAdmin) {
    # 创建一个启动对象
    $psi = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($args.Count -gt 0) { $psi.Arguments += " " + ($args -join " ") }
    $psi.Verb = "runas"  # 请求提升权限
    $psi.WorkingDirectory = Get-Location
    $psi.WindowStyle = 'Normal'  # 使用正常窗口

    # 启动进程
    try {
        Write-Host "需要管理员权限运行此脚本，正在请求权限..." -ForegroundColor Yellow
        $p = [System.Diagnostics.Process]::Start($psi)
        # 立即退出当前进程，避免显示两个窗口
        exit
    }
    catch {
        Write-Host "获取管理员权限失败: $_" -ForegroundColor Red
        Read-Host "按Enter退出"
        exit 1
    }
}

# 版本
$version="1.2.0"

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

# 显示管理员权限提示
Write-Host "以管理员权限运行..." -ForegroundColor Green

# 显示启动标志
Write-Host @"
===================================================
         ZeroTier 便携版启动脚本
         版本: $version
         日期: 2025-04-10
===================================================
"@ -ForegroundColor Cyan

# 准备运行环境 - 如果从EXE运行，则解压文件到临时目录
if ($runtimePath -ne $PSScriptRoot) {
    Write-Host "准备运行环境..." -ForegroundColor Yellow

    # 创建存储临时文件的目录路径变量
    $binDest = Join-Path $runtimePath "bin"
    $psDest = Join-Path $runtimePath "ps"
    $binSrc = Join-Path $baseDir "bin"
    $psSrc = Join-Path $baseDir "ps"

    # 清理可能存在的旧临时目录
    if (Test-PathSafely -Path $runtimePath) {
        Remove-Item $runtimePath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "已清理旧的临时目录" -ForegroundColor Yellow
    }

    # 创建新的临时目录
    New-Item -ItemType Directory -Path $runtimePath -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path $binDest -Force -ErrorAction SilentlyContinue | Out-Null
    New-Item -ItemType Directory -Path $psDest -Force -ErrorAction SilentlyContinue | Out-Null

    # 检查要复制的源文件夹是否存在
    if (-not (Test-PathSafely -Path $binSrc -Type "目录")) {
        # 如果源bin目录不存在，在exe模式下查找内嵌的资源
        Write-Host "在EXE模式下查找内嵌bin资源..." -ForegroundColor Yellow

        # 确保临时目录已创建
        New-Item -ItemType Directory -Path $binDest -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $binDest "tap-driver") -Force -ErrorAction SilentlyContinue | Out-Null

        # 写入内部脚本解释说明
        Write-Host "如果您是从EXE运行，文件会自动从内嵌资源中解压出来" -ForegroundColor Green
    }
    else {
        # 复制正常的文件夹内容
        Write-Host "复制bin目录到临时路径..." -ForegroundColor Yellow
        Copy-Item -Path "$binSrc\*" -Destination $binDest -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-PathSafely -Path $psSrc -Type "目录")) {
        # 如果源ps目录不存在，在exe模式下创建空目录
        Write-Host "在EXE模式下查找内嵌ps资源..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $psDest -Force -ErrorAction SilentlyContinue | Out-Null
    }
    else {
        # 复制正常的文件夹内容
        Write-Host "复制ps目录到临时路径..." -ForegroundColor Yellow
        Copy-Item -Path "$psSrc\*" -Destination $psDest -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "运行环境准备完成" -ForegroundColor Green
}

# 定义数据目录（在U盘上的隐藏文件夹）
$dataPath = Join-Path -Path $baseDir -ChildPath "ZeroTierData"

# 如果数据目录不存在，创建并设置为隐藏
if (-not (Test-PathSafely -Path $dataPath -Type "目录" -CreateIfDirectory)) {
    # 安全性检查 - 目录创建失败的情况
    Write-Host "无法创建数据目录，尝试使用临时目录..." -ForegroundColor Yellow
    $dataPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "ZeroTierData_Temp"
    New-Item -ItemType Directory -Path $dataPath -Force -ErrorAction SilentlyContinue | Out-Null
}
else {
    # 尝试设置隐藏属性
    try {
        $folder = Get-Item $dataPath -Force -ErrorAction SilentlyContinue
        if ($folder) {
            $folder.Attributes = $folder.Attributes -bor [System.IO.FileAttributes]::Hidden
            Write-Host "已创建数据存储目录: $dataPath (隐藏)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "无法设置文件夹隐藏属性: $_" -ForegroundColor Yellow
    }
}

# 确保networks.d子目录存在
$networksDir = Join-Path -Path $dataPath -ChildPath "networks.d"
if (-not (Test-PathSafely -Path $networksDir -Type "目录" -CreateIfDirectory)) {
    Write-Host "无法创建networks.d子目录" -ForegroundColor Yellow
}

# 更新路径变量以使用新的目录结构
$binPath = Join-Path -Path $runtimePath -ChildPath "bin"
$psPath = Join-Path -Path $runtimePath -ChildPath "ps"
$zerotierExe = Join-Path -Path $binPath -ChildPath "zerotier-one_x64.exe"
$tapDriverPath = Join-Path -Path $binPath -ChildPath "tap-driver"
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
        Write-Host "错误: 无法找到关键组件 $($component.Key): $($component.Value)" -ForegroundColor Red
        $missingComponents = $true
    }
    else {
        Write-Host "✅ 已找到组件: $($component.Key)" -ForegroundColor Green
    }
}

# 如果关键组件缺失，提供详细诊断信息
if ($missingComponents) {
    Write-Host "`n诊断信息:" -ForegroundColor Yellow
    Write-Host "运行模式: $execMode" -ForegroundColor Yellow
    Write-Host "基础目录: $baseDir" -ForegroundColor Yellow
    Write-Host "运行时目录: $runtimePath" -ForegroundColor Yellow
    Write-Host "数据目录: $dataPath" -ForegroundColor Yellow

    if ($execMode -eq "EXE模式") {
        Write-Host "`nEXE模式下可能的问题:" -ForegroundColor Yellow
        Write-Host "1. 打包过程中未正确包含依赖文件" -ForegroundColor Yellow
        Write-Host "2. 资源提取到临时目录失败" -ForegroundColor Yellow
        Write-Host "3. 临时目录访问权限不足" -ForegroundColor Yellow

        Write-Host "`n请尝试以下解决方案:" -ForegroundColor Yellow
        Write-Host "1. 使用管理员权限运行此EXE" -ForegroundColor Yellow
        Write-Host "2. 检查杀毒软件是否阻止了文件解压" -ForegroundColor Yellow
        Write-Host "3. 尝试重新打包程序，确保包含所有依赖文件" -ForegroundColor Yellow
    }

    Write-Host "`n请确保文件结构完整，必要的文件都在正确的位置。" -ForegroundColor Red
    Read-Host "按Enter退出"
    exit 1
}

# 检查身份文件是否存在
$identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
$identityPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public"
$isNewIdentity = $false

# 添加候选界面，让用户选择后续操作
Clear-Host
Write-Host @"
===================================================
      ZeroTier 便携版安装管理
      版本: $version
      日期: 2025-04-10
===================================================

"@ -ForegroundColor Cyan

Write-Host "请选择操作:" -ForegroundColor Yellow
Write-Host "1. 安装 ZeroTier" -ForegroundColor Green
Write-Host "2. 卸载 ZeroTier" -ForegroundColor Yellow
Write-Host "3. 退出" -ForegroundColor Red

$installChoice = Read-Host "`n请输入选择 (1-3) [默认:1]"

# 如果用户没有输入，默认选择安装
if ([string]::IsNullOrEmpty($installChoice)) {
    $installChoice = "1"
}

# 根据用户选择执行相应操作
switch ($installChoice) {
    "1" {
        Write-Host "`n准备安装 ZeroTier..." -ForegroundColor Green
        # 继续执行安装过程，检查身份文件
        if (-not (Test-Path $identityFile)) {
            $isNewIdentity = $true
            Write-Host "未找到身份文件，需要生成新的身份..." -ForegroundColor Yellow
            Write-Host "按任意键进入身份编辑界面..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

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
                    $publicKeyContent = Get-Content -Path $identityPublicFile -Raw -ErrorAction SilentlyContinue
                    if ($publicKeyContent) {
                        $nodeId = $publicKeyContent.Substring(0, 10)  # 取前10个字符作为节点ID
                        Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
                    }
                }
                else {
                    Write-Host "警告：未检测到身份文件生成，请手动确认是否已创建身份" -ForegroundColor Red
                    $continue = Read-Host "是否继续安装过程? (Y/N)"
                    if ($continue -ne "Y" -and $continue -ne "y") {
                        Write-Host "操作已取消。" -ForegroundColor Red
                        exit 1
                    }
                }
            }
        }
    }
    "2" {
        Write-Host "`n准备卸载 ZeroTier..." -ForegroundColor Yellow

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
                Write-Host "正在删除系统中的zerotier-cli..." -ForegroundColor Yellow
                Remove-Item -Force $cliSystemPath
                Write-Host "已成功删除zerotier-cli" -ForegroundColor Green
            }

            if (Test-Path $idtoolSystemPath) {
                Write-Host "正在删除系统中的zerotier-idtool..." -ForegroundColor Yellow
                Remove-Item -Force $idtoolSystemPath
                Write-Host "已成功删除zerotier-idtool" -ForegroundColor Green
            }

            # 停止并删除TAP服务
            Write-Host "正在检查并卸载TAP驱动服务..." -ForegroundColor Yellow
            $service = Get-Service -Name $tapServiceName -ErrorAction SilentlyContinue
            if ($service) {
                Write-Host "找到TAP驱动服务: $tapServiceName，正在停止..." -ForegroundColor Yellow
                try {
                    Stop-Service -Name $tapServiceName -Force -ErrorAction Stop
                    Write-Host "服务已停止，正在删除..." -ForegroundColor Yellow
                    # 使用SC删除服务
                    $scOutput = sc.exe delete $tapServiceName 2>&1
                    if ($LASTEXITCODE -eq 0 -or $scOutput -match "成功") {
                        Write-Host "TAP驱动服务成功删除" -ForegroundColor Green
                    } else {
                        Write-Host "警告: TAP驱动服务删除返回未知状态: $LASTEXITCODE" -ForegroundColor Yellow
                        Write-Host "输出: $scOutput" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "停止或删除TAP驱动服务失败: $_" -ForegroundColor Red
                }
            } else {
                Write-Host "未找到TAP驱动服务" -ForegroundColor Yellow
            }

            # 卸载TAP驱动
            Write-Host "正在检查并卸载TAP驱动文件..." -ForegroundColor Yellow

            # 查找驱动的OEM名称
            $driverInfo = pnputil /enum-drivers | Select-String -Pattern $tapDriverName -SimpleMatch
            if ($driverInfo) {
                # 从驱动信息中提取OEM#名称
                $oemPattern = "oem\d+\.inf"
                $matches = [regex]::Matches($driverInfo, $oemPattern)
                if ($matches.Count -gt 0) {
                    $oemName = $matches[0].Value
                    Write-Host "找到TAP驱动: $oemName，正在卸载..." -ForegroundColor Yellow

                    try {
                        # 使用pnputil删除驱动
                        $uninstallOutput = pnputil /delete-driver $oemName /force 2>&1

                        # 检查卸载结果
                        if ($LASTEXITCODE -eq 0 -or $uninstallOutput -match "成功") {
                            Write-Host "TAP驱动成功卸载" -ForegroundColor Green
                        }
                        else {
                            Write-Host "警告: TAP驱动卸载返回未知状态: $LASTEXITCODE" -ForegroundColor Yellow
                            Write-Host "输出: $uninstallOutput" -ForegroundColor Yellow
                        }
                    }
                    catch {
                        Write-Host "卸载TAP驱动失败: $_" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "警告: 找到TAP驱动但无法确定OEM名称" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "未找到已安装的TAP驱动" -ForegroundColor Yellow
            }

            Write-Host "`nZeroTier 已成功卸载！" -ForegroundColor Green
            Write-Host "卸载操作完成。" -ForegroundColor Green
            Read-Host "按Enter退出"
            exit 0
        }
        catch {
            Write-Host "卸载ZeroTier失败: $_" -ForegroundColor Red
            Read-Host "按Enter退出"
            exit 1
        }
    }
    "3" {
        Write-Host "`n操作已取消，正在退出..." -ForegroundColor Yellow
        exit 0
    }
    default {
        Write-Host "`n无效选择，默认执行安装操作..." -ForegroundColor Red
        Start-Sleep -Seconds 2
        # 继续执行安装流程
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
$tapDriverSys = Join-Path -Path $tapDriverPath -ChildPath "zttap300.sys"
$tapDriverCat = Join-Path -Path $tapDriverPath -ChildPath "zttap300.cat"
# 定义驱动程序的服务名称，用于后续卸载
$tapServiceName = "zttap300"

# 检查驱动是否已安装
$tapInstalled = $false
$driverInfo = pnputil /enum-drivers | Select-String -Pattern "zttap300" -SimpleMatch

if ($driverInfo) {
    $tapInstalled = $true
    Write-Host "TAP驱动已安装" -ForegroundColor Green
}
else {
    Write-Host "安装TAP驱动..." -ForegroundColor Yellow

    # 1. 验证CAT签名
    Write-Host "验证驱动签名..." -ForegroundColor Yellow
    try {
        $catSig = Get-AuthenticodeSignature $tapDriverCat
        if ($catSig.Status -eq "Valid") {
            Write-Host "驱动签名验证通过" -ForegroundColor Green
        } else {
            Write-Host "警告: 驱动签名无效: $($catSig.StatusMessage)" -ForegroundColor Yellow
            $continueUnsigned = Read-Host "驱动签名无效，是否继续安装? (Y/N)"
            if ($continueUnsigned -ne "Y" -and $continueUnsigned -ne "y") {
                Write-Host "操作已取消。" -ForegroundColor Red
                exit 1
            }
        }
    }
    catch {
        Write-Host "警告: 验证驱动签名失败: $_" -ForegroundColor Yellow
    }

    # 2. 使用pnputil安装INF驱动
    try {
        Write-Host "正在安装INF驱动..." -ForegroundColor Yellow
        $pnputilOutput = pnputil /add-driver "$tapDriverInf" /install 2>&1
        # 检查输出是否包含成功信息
        if ($LASTEXITCODE -eq 0 -or $pnputilOutput -match "成功") {
            Write-Host "TAP驱动INF安装成功" -ForegroundColor Green
            $tapInstalled = $true
        }
        else {
            throw "pnputil返回错误代码: $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "警告: TAP驱动INF安装失败: $_" -ForegroundColor Red
        Write-Host "原始输出: $pnputilOutput" -ForegroundColor Red
        $continueAnyway = Read-Host "是否继续尝试注册SYS服务? (Y/N)"
        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-Host "操作已取消。" -ForegroundColor Red
            exit 1
        }
    }

    # 3. 注册SYS服务
    try {
        Write-Host "正在注册TAP驱动服务..." -ForegroundColor Yellow
        # 检查服务是否已存在
        $existingService = Get-Service -Name $tapServiceName -ErrorAction SilentlyContinue

        if (-not $existingService) {
            # 注册新服务
            New-Service -Name $tapServiceName -BinaryPathName $tapDriverSys -DisplayName "ZeroTier TAP Driver" -StartupType Manual
            Write-Host "服务注册成功" -ForegroundColor Green
        } else {
            Write-Host "服务已存在，尝试启动服务" -ForegroundColor Yellow
        }

        # 尝试启动服务
        Start-Service -Name $tapServiceName
        Write-Host "TAP驱动服务启动成功" -ForegroundColor Green
        $tapInstalled = $true
    }
    catch {
        Write-Host "警告: TAP驱动服务注册/启动失败: $_" -ForegroundColor Red
        Write-Host "ZeroTier可能无法正常工作，网络连接可能受限。" -ForegroundColor Red
        $continueAnyway = Read-Host "是否继续启动ZeroTier? (Y/N)"
        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-Host "操作已取消。" -ForegroundColor Red
            exit 1
        }
    }
}

# 添加CLI和IDTool到系统环境（优先创建符号链接，失败则复制文件）
Write-Host "正在添加ZeroTier命令行工具到系统环境..." -ForegroundColor Yellow

# 定义系统目标位置
$systemCmdPath = "C:\Windows\System32"
$cliSystemPath = "$systemCmdPath\zerotier-cli.bat"
$idtoolSystemPath = "$systemCmdPath\zerotier-idtool.bat"

try {
    # 首先尝试创建符号链接（需要管理员权限）
    Write-Host "尝试创建命令行工具符号链接..." -ForegroundColor Yellow

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
        Write-Host "符号链接创建成功!" -ForegroundColor Green
    } else {
        throw "符号链接创建失败"
    }
}
catch {
    Write-Host "符号链接创建失败: $_，使用文件复制方式..." -ForegroundColor Yellow

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
        Write-Host "命令行工具已通过文件复制方式添加到系统路径" -ForegroundColor Green
    }
    catch {
        Write-Host "添加命令行工具到系统环境失败: $_" -ForegroundColor Red
        $continueAnyway = Read-Host "是否继续运行ZeroTier? (Y/N)"
        if ($continueAnyway -ne "Y" -and $continueAnyway -ne "y") {
            Write-Host "操作已取消。" -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host "命令行工具已配置完成" -ForegroundColor Green
Write-Host "您现在可以在任何命令提示符中使用 'zerotier-cli' 和 'zerotier-idtool' 命令。" -ForegroundColor Green

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
    Write-Host "`n检测到Ctrl+C，正在准备清理环境..." -ForegroundColor Yellow
})

try {
    # 启动ZeroTier
    $process = Start-Process -FilePath $zerotierExe -ArgumentList $startArgs -PassThru -NoNewWindow
    Write-Host "ZeroTier进程已启动，PID: $($process.Id)" -ForegroundColor Green

    # 等待ZeroTier初始化
    Write-Host "等待ZeroTier初始化..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5

    # 获取并显示节点状态
    Write-Host "`n正在获取节点状态..." -ForegroundColor Yellow
    try {
        $nodeStatus = & "$zerotierExe" -q -D"$dataPath" "info" 2>&1

        # 将结果转换为字符串以确保一致处理
        $nodeStatusStr = $nodeStatus | Out-String
        Write-Host "原始状态: $nodeStatusStr" -ForegroundColor Gray

        # 检查是否有200状态码表示成功
        if ($nodeStatusStr -match "200") {
            Write-Host "ZeroTier服务启动成功" -ForegroundColor Green

            # 尝试提取节点ID和状态（如果可用）
            if ($nodeStatusStr -match "200 info (\w+)") {
                $nodeId = $Matches[1]
                Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
            }

            # 检查各种可能的状态
            if ($nodeStatusStr -match "ONLINE") {
                Write-Host "节点状态: ONLINE (已连接)" -ForegroundColor Green
                Write-Host "节点已成功连接到ZeroTier网络！" -ForegroundColor Green
            }
            elseif ($nodeStatusStr -match "TUNNELED") {
                Write-Host "节点状态: TUNNELED (通过隧道连接)" -ForegroundColor Green
                Write-Host "节点已成功通过隧道连接到ZeroTier网络！" -ForegroundColor Green
            }
            elseif ($nodeStatusStr -match "OFFLINE") {
                Write-Host "节点状态: OFFLINE (离线)" -ForegroundColor Yellow
                Write-Host "节点服务已启动，但尚未连接到网络。" -ForegroundColor Yellow
            }
            else {
                Write-Host "节点状态: 未知" -ForegroundColor Yellow
                Write-Host "节点状态未明确显示，服务已启动但可能需要检查网络设置。" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "警告: 无法确认ZeroTier服务是否正常启动" -ForegroundColor Red
        }

        # 显示已加入的网络，完全重写这部分，避免使用数组索引
        Write-Host "`n已加入的网络：" -ForegroundColor Cyan
        try {
            $networks = & "$zerotierExe" -q -D"$dataPath" "listnetworks" 2>&1

            # 转换为字符串便于处理
            $networksStr = $networks | Out-String
            Write-Host "原始网络列表: $networksStr" -ForegroundColor Gray

            # 拆分成行来逐行处理
            $networkLines = $networksStr -split "`n"
            $foundNetwork = $false

            foreach ($line in $networkLines) {
                if ([string]::IsNullOrEmpty($line)) { continue }

                if ($line -match "200 listnetworks\s+([0-9a-f]+)") {
                    $foundNetwork = $true
                    $networkId = $Matches[1]
                    Write-Host "`n- 网络ID: $networkId" -ForegroundColor Green

                    # 尝试提取更多信息，但避免使用索引访问
                    if ($line -match "200 listnetworks\s+[0-9a-f]+\s+(\S+)") {
                        $networkName = $Matches[1]
                        Write-Host "  名称: $networkName" -ForegroundColor Green
                    }

                    # 查找状态信息
                    if ($line -match "OK|PUBLIC|PRIVATE") {
                        Write-Host "  状态: 已连接" -ForegroundColor Green
                    }

                    # 查找IP信息
                    if ($line -match "(\d+\.\d+\.\d+\.\d+/\d+)") {
                        $ip = $Matches[1]
                        Write-Host "  IP地址: $ip" -ForegroundColor Green
                    }
                }
            }

            if (-not $foundNetwork) {
                Write-Host "尚未加入任何网络" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "获取网络列表失败: $_" -ForegroundColor Red
            Write-Host "尚未加入任何网络或网络信息获取失败" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "获取节点状态失败: $_" -ForegroundColor Red
        Write-Host "无法确定节点状态，请检查ZeroTier服务是否正常启动" -ForegroundColor Red
    }
    Start-Sleep -Seconds 4
    Clear-Host
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

    # 保持脚本运行，直到用户按Ctrl+C或进程终止
    Write-Host "按Ctrl+C停止ZeroTier并退出..." -ForegroundColor Yellow
    while ($true) {
        # 检查是否按下了Ctrl+C
        if ($global:ctrlCPressed) {
            Write-Host "正在处理Ctrl+C请求，准备退出..." -ForegroundColor Yellow
            break
        }

        # 检查ZeroTier进程是否仍在运行
        if (-not (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
            Write-Host "ZeroTier进程已终止，正在退出..." -ForegroundColor Red
            break
        }

        # 短暂睡眠以减少CPU使用
        Start-Sleep -Milliseconds 500
    }
}
catch {
    Write-Host "ZeroTier运行过程中出错: $_" -ForegroundColor Red
}
finally {
    # 清理工作
    Write-Host "正在执行退出清理..." -ForegroundColor Yellow

    # 1. 停止ZeroTier进程
    if ($process -and (Get-Process -Id $process.Id -ErrorAction SilentlyContinue)) {
        Write-Host "正在停止ZeroTier进程..." -ForegroundColor Yellow
        try {
            $process.Kill()
            $process.WaitForExit(5000)
            Write-Host "ZeroTier进程已停止" -ForegroundColor Green
        }
        catch {
            Write-Host "停止ZeroTier进程失败: $_" -ForegroundColor Red
        }
    }

    # 2. 清理环境
    Clean-Environment -systemCmdPath "C:\Windows\System32" -tempPath $runtimePath

    Write-Host "ZeroTier便携版已完全退出" -ForegroundColor Green
    Write-Host "您可以安全地移除U盘了" -ForegroundColor Cyan

    # 等待用户确认
    if (-not $global:ctrlCPressed) {
        Read-Host "按Enter退出"
    }
}