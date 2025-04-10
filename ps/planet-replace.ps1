# ZeroTier便携版Planet文件替换工具
# 此脚本用于替换ZeroTier的Planet文件，支持从网络下载或使用本地文件
# 作者: LingNc
# 版本: 1.1.2
# 日期: 2025-04-10

# 参数定义
param (
    [switch]$help = $false,
    [switch]$h = $false
)

# 版本
$version = "1.1.2"
# 检查管理员权限并自动提升
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 如果没有管理员权限，则使用提升的方式重新启动
if (-not $isAdmin) {
    Write-Host "需要管理员权限运行此脚本，正在请求权限..." -ForegroundColor Yellow

    # 创建一个启动对象
    $psi = New-Object System.Diagnostics.ProcessStartInfo "PowerShell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($args.Count -gt 0) { $psi.Arguments += " " + ($args -join " ") }
    $psi.Verb = "runas"  # 请求提升权限
    $psi.WorkingDirectory = Get-Location
    $psi.WindowStyle = 'Normal'  # 使用正常窗口

    # 启动进程
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        # 等待进程完成
        $p.WaitForExit()
        exit $p.ExitCode  # 使用子进程的退出代码
    }
    catch {
        Write-Host "获取管理员权限失败: $_" -ForegroundColor Red
        Read-Host "按Enter退出"
        exit 1
    }
    exit
}

# 显示帮助信息
function Show-Help {
    Write-Host @"
===================================================
      ZeroTier Planet文件替换工具 - 帮助信息
      版本: $version
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
Clear-Host
Write-Host @"
===================================================
      ZeroTier 便携版 Planet 文件替换工具
      版本: $version
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

# 显示菜单函数
function Show-Menu {
    Clear-Host
    Write-Host @"
===================================================
      ZeroTier 便携版 Planet 文件替换工具
      版本: $version
      日期: 2025-04-10
===================================================
"@ -ForegroundColor Cyan

    Write-Host "`n请选择 Planet 文件来源:" -ForegroundColor Yellow
    Write-Host "1. 从网络下载" -ForegroundColor Green
    Write-Host "2. 使用本地文件" -ForegroundColor Green
    Write-Host "3. 查看当前Planet信息" -ForegroundColor Green
    Write-Host "4. 恢复默认Planet" -ForegroundColor Green
    Write-Host "5. 退出" -ForegroundColor Red

    $choice = Read-Host "`n请输入选项 (1-5) [默认:5]"
    # 如果用户没有输入，默认选择退出
    if ([string]::IsNullOrEmpty($choice)) {
        return "5"
    }
    return $choice
}

# 查看当前Planet信息
function Show-PlanetInfo {
    Clear-Host
    Write-Host @"
===================================================
      查看当前Planet服务器信息
      版本: $version
===================================================
"@ -ForegroundColor Cyan

    # 检查Planet文件是否存在
    if (-not (Test-Path $planetFile)) {
        Write-Host "`n当前未找到Planet文件: $planetFile" -ForegroundColor Yellow
        Write-Host "这意味着ZeroTier将使用默认内置的Planet服务器。" -ForegroundColor Cyan
    }
    else {
        # 分析Planet文件内容
        Write-Host "`nPlanet文件信息:" -ForegroundColor Cyan
        Write-Host "路径: $planetFile" -ForegroundColor Yellow
        Write-Host "大小: $((Get-Item $planetFile).Length) 字节" -ForegroundColor Yellow
        Write-Host "修改时间: $((Get-Item $planetFile).LastWriteTime)" -ForegroundColor Yellow

        # 尝试解析Planet文件内容
        Write-Host "`n尝试解析Planet文件内容..." -ForegroundColor Yellow

        # 先检查ZeroTier是否正在运行
        $ztRunning = $false
        $processes = Get-Process -Name "zerotier-one*" -ErrorAction SilentlyContinue
        if ($processes) {
            $ztRunning = $true
            Write-Host "`nZeroTier已运行，尝试获取活动Planet信息..." -ForegroundColor Green

            # 从peers命令输出中提取PLANET信息
            try {
                $peersOutput = & "$zerotierExe" -q -D"$dataPath" "peers" 2>&1
                $planetPeers = $peersOutput | Where-Object { $_ -match "PLANET" }

                if ($planetPeers) {
                    Write-Host "`n当前活动的Planet节点:" -ForegroundColor Green
                    foreach ($peer in $planetPeers) {
                        Write-Host $peer -ForegroundColor Cyan
                    }
                }
                else {
                    Write-Host "`n未找到活动的Planet节点" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "`n获取活动Planet信息失败: $_" -ForegroundColor Red
            }
        }
        else {
            Write-Host "`nZeroTier未运行，无法获取活动Planet信息" -ForegroundColor Yellow
            Write-Host "启动ZeroTier后可获取更详细的Planet连接信息" -ForegroundColor Yellow
        }

        # 无论ZeroTier是否运行，都尝试直接解析Planet文件
        try {
            # 尝试读取Planet文件的二进制内容并查找IP地址模式
            $planetBytes = [System.IO.File]::ReadAllBytes($planetFile)
            $ipv4Pattern = [byte[]]@(0,0,0,0)  # IP地址前的标记
            $ipAddresses = @()

            for ($i = 0; $i -lt $planetBytes.Length - 8; $i++) {
                # 检查是否可能是IPv4地址标记
                if ($planetBytes[$i] -ge 1 -and $planetBytes[$i] -le 5 -and
                    $planetBytes[$i+1] -eq 0 -and
                    $planetBytes[$i+2] -eq 0 -and
                    $planetBytes[$i+3] -eq 0) {

                    # 可能找到一个IPv4地址，尝试解析
                    $ip1 = $planetBytes[$i+4]
                    $ip2 = $planetBytes[$i+5]
                    $ip3 = $planetBytes[$i+6]
                    $ip4 = $planetBytes[$i+7]

                    # 只保留有效的IP地址格式
                    if ($ip1 -le 255 -and $ip2 -le 255 -and $ip3 -le 255 -and $ip4 -le 255) {
                        $ipStr = "$ip1.$ip2.$ip3.$ip4"
                        if (-not $ipAddresses.Contains($ipStr)) {
                            $ipAddresses += $ipStr
                        }
                    }
                }
            }

            if ($ipAddresses.Count -gt 0) {
                Write-Host "`n从Planet文件中检测到的可能服务器地址:" -ForegroundColor Green
                foreach ($ip in $ipAddresses) {
                    Write-Host "- $ip" -ForegroundColor Cyan
                }
                Write-Host "`n注意: 这是通过二进制分析推测的结果，可能不完全准确" -ForegroundColor Yellow
            }
            else {
                Write-Host "`n无法从Planet文件中提取服务器地址" -ForegroundColor Yellow
            }

            # 尝试分析文件头部信息
            try {
                $fileHeader = $planetBytes[0..32] -join ","
                Write-Host "`nPlanet文件头部分析:" -ForegroundColor Yellow
                Write-Host "文件头部字节: $fileHeader" -ForegroundColor Cyan

                # 查找可能的字符串标识
                $asciiBytes = [System.Text.Encoding]::ASCII.GetBytes("PLANET")
                $idx = [Array]::IndexOf($planetBytes, $asciiBytes[0])
                $found = $false

                while ($idx -ge 0 -and $idx -lt ($planetBytes.Length - 6)) {
                    $found = $true
                    for ($j = 1; $j -lt 6; $j++) {
                        if (($idx + $j) -ge $planetBytes.Length -or $planetBytes[$idx + $j] -ne $asciiBytes[$j]) {
                            $found = $false
                            break
                        }
                    }

                    if ($found) {
                        Write-Host "在文件中发现'PLANET'标识位置: $idx" -ForegroundColor Green
                        break
                    }

                    $idx = [Array]::IndexOf($planetBytes, $asciiBytes[0], $idx + 1)
                }

                if (-not $found) {
                    Write-Host "未在文件中找到'PLANET'标识" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "分析文件头部时出错: $_" -ForegroundColor Red
            }

            # 提供使用建议
            Write-Host "`n要查看更详细的Planet连接信息，请在启动ZeroTier后使用以下命令:" -ForegroundColor Green
            Write-Host "zerotier-cli.bat peers | Select-String 'PLANET'" -ForegroundColor Cyan
        }
        catch {
            Write-Host "`n解析Planet文件失败: $_" -ForegroundColor Red
        }
    }

    Write-Host "`n如要替换Planet文件，请在主菜单中选择相应选项" -ForegroundColor Yellow
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

# 从网络下载Planet文件
function Download-PlanetFile {
    Write-Host "提示: 输入'q'或按'Esc'键可随时返回主菜单" -ForegroundColor Yellow

    # 提示用户提供下载URL
    Write-Host "`n请输入Planet文件的下载URL" -ForegroundColor Green

    # 读取用户输入的函数，同时支持q和Esc键退出
    function Read-InputWithEsc {
        $inputChars = @()
        $escPressed = $false

        Write-Host -NoNewline "> " # 添加提示符

        while ($true) {
            # 使用ReadKey读取一个字符
            $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            # 如果是Esc键，设置标志并退出循环
            if ($key.VirtualKeyCode -eq 27) { # 27是Esc键的虚拟键码
                $escPressed = $true
                break
            }

            # 如果是回车键，退出循环
            if ($key.VirtualKeyCode -eq 13) { # 13是回车键的虚拟键码
                Write-Host "" # 换行
                break
            }

            # 如果是退格键
            if ($key.VirtualKeyCode -eq 8) { # 8是退格键的虚拟键码
                if ($inputChars.Count -gt 0) {
                    # 删除最后一个字符
                    $inputChars = $inputChars[0..($inputChars.Count-2)]

                    # 在控制台上模拟退格效果
                    Write-Host -NoNewline "`b `b"
                }
                continue
            }

            # 将字符添加到数组并显示
            if ($key.Character -ne 0) { # 确保是有效字符
                $inputChars += $key.Character
                Write-Host -NoNewline $key.Character
            }
        }

        # 如果按了Esc键，返回特殊标记
        if ($escPressed) {
            return "ESC"
        }

        # 将字符数组连接成字符串返回
        if ($inputChars.Count -eq 0) {
            return ""
        }
        else {
            return [string]::Join("", $inputChars)
        }
    }

    # 使用新函数读取用户输入
    $downloadUrl = Read-InputWithEsc

    # 检查是否按了ESC键或输入了q
    if ($downloadUrl -eq "ESC" -or $downloadUrl -eq "q" -or $downloadUrl -eq "Q") {
        Write-Host "`n操作已取消，返回主菜单..." -ForegroundColor Yellow
        return
    }

    # 简单验证URL格式
    if (-not ($downloadUrl -match "^https?://")) {
        Write-Host "错误: URL必须以http://或https://开头" -ForegroundColor Red
        Write-Host "按任意键返回主菜单..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
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
        Write-Host "按任意键返回主菜单..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    # 检查下载文件是否为空
    if ((Get-Item $tempFile).Length -eq 0) {
        Write-Host "错误: 下载的文件为空!" -ForegroundColor Red
        Remove-Item -Path $tempFile -Force
        Write-Host "按任意键返回主菜单..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
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
        Write-Host "按任意键返回主菜单..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
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

# 使用本地文件替换Planet
function Use-LocalPlanetFile {
    # 提示用户提供本地文件路径
    Write-Host "(输入'q'并按Enter返回主菜单，或按'Esc'键立即返回)" -ForegroundColor Yellow
    Write-Host "`n请输入本地Planet文件的完整路径" -ForegroundColor Green

    # 读取用户输入的函数，同时支持q和Esc键退出
    function Read-InputWithEsc {
        $inputChars = @()
        $escPressed = $false

        Write-Host -NoNewline "> " # 添加提示符

        while ($true) {
            # 使用ReadKey读取一个字符
            $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            # 如果是Esc键，设置标志并退出循环
            if ($key.VirtualKeyCode -eq 27) { # 27是Esc键的虚拟键码
                $escPressed = $true
                break
            }

            # 如果是回车键，退出循环
            if ($key.VirtualKeyCode -eq 13) { # 13是回车键的虚拟键码
                Write-Host "" # 换行
                break
            }

            # 如果是退格键
            if ($key.VirtualKeyCode -eq 8) { # 8是退格键的虚拟键码
                if ($inputChars.Count -gt 0) {
                    # 删除最后一个字符
                    $inputChars = $inputChars[0..($inputChars.Count-2)]

                    # 在控制台上模拟退格效果
                    Write-Host -NoNewline "`b `b"
                }
                continue
            }

            # 将字符添加到数组并显示
            if ($key.Character -ne 0) { # 确保是有效字符
                $inputChars += $key.Character
                Write-Host -NoNewline $key.Character
            }
        }

        # 如果按了Esc键，返回特殊标记
        if ($escPressed) {
            return "ESC"
        }

        # 将字符数组连接成字符串返回
        if ($inputChars.Count -eq 0) {
            return ""
        }
        else {
            return [string]::Join("", $inputChars)
        }
    }

    # 使用新函数读取用户输入
    $localFile = Read-InputWithEsc

    # 检查是否按了ESC键或输入了q
    if ($localFile -eq "ESC" -or $localFile -eq "q" -or $localFile -eq "Q") {
        Write-Host "`n操作已取消，返回主菜单..." -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $localFile)) {
        Write-Host "错误: 文件不存在: $localFile" -ForegroundColor Red
        Write-Host "按任意键返回主菜单..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    if ((Get-Item $localFile).Length -eq 0) {
        Write-Host "错误: 文件为空: $localFile" -ForegroundColor Red
        Write-Host "按任意键返回主菜单..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
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
        Read-Host "按Enter返回主菜单"
        return
    }

    Write-Host @"

Planet文件已成功替换!
如需启动ZeroTier，请运行根目录下的 start.ps1 脚本。
"@ -ForegroundColor Green
}

# 主循环
do {
    $choice = Show-Menu

    switch ($choice) {
        "1" {
            Clear-Host
            Write-Host "===== 从网络下载Planet文件 =====" -ForegroundColor Cyan
            Download-PlanetFile
        }
        "2" {
            Clear-Host
            Write-Host "===== 使用本地Planet文件 =====" -ForegroundColor Cyan
            Use-LocalPlanetFile
        }
        "3" {
            Clear-Host
            Write-Host "===== 查看当前Planet信息 =====" -ForegroundColor Cyan
            Show-PlanetInfo
        }
        "4" {
            Clear-Host
            Write-Host "===== 恢复默认Planet =====" -ForegroundColor Cyan
            Restore-DefaultPlanet
        }
        "5" {
            Write-Host "退出程序" -ForegroundColor Yellow
            exit 0
        }
        default {
            Write-Host "无效选择，将在3秒后返回主菜单..." -ForegroundColor Red
            Start-Sleep -Seconds 3
        }
    }

    # 在每个操作完成后暂停
    if ($choice -ne "5") {
        Write-Host "`n操作完成。" -ForegroundColor Green
        Read-Host "按Enter返回主菜单..."
    }

} while ($choice -ne "5")