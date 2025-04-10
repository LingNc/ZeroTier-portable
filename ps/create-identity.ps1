# ZeroTier便携版身份管理脚本
# 此脚本用于生成、备份和导入ZeroTier身份
# 作者: GitHub Copilot
# 版本: 1.1.5
# 日期: 2025-04-10

# 参数定义
param (
    [switch]$help = $false,
    [switch]$h = $false
)
# 版本
$version = "1.1.5"
# 检查是否显示帮助
if ($help -or $h) {
    Write-Host @"
===================================================
      ZeroTier 便携版身份管理工具 - 帮助信息
      版本: $version
===================================================

描述:
    该脚本用于管理ZeroTier的身份文件，包括生成、导入、备份和查看身份。

用法:
    create-identity.ps1 [-help|-h]

参数:
    -help, -h    显示此帮助信息

功能:
    1. 生成新的ZeroTier身份 - 创建新的身份文件，显示节点ID
    2. 导入现有身份文件 - 从其他位置导入身份文件到当前数据目录
    3. 备份当前身份 - 将当前身份备份到指定位置
    4. 查看当前身份 - 显示当前身份信息和节点ID

注意:
    - 此脚本需要管理员权限运行
    - 覆盖现有身份将导致节点ID改变，可能需要重新加入网络

相关命令:
    也可通过 'zerotier-idtool inter' 从任何位置启动此工具
"@
    exit 0
}

# 需要管理员权限
# 检查管理员权限并自动提升
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 如果没有管理员权限，则使用提升的方式重新启动
if (-not $isAdmin) {
    try {
        # 创建提升进程而不打开新窗口
        $arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($args.Count -gt 0) {
            $arguments += " " + ($args -join " ")
        }

        Write-Host "需要管理员权限运行此脚本，正在请求权限..." -ForegroundColor Yellow
        Start-Process powershell -Verb RunAs -ArgumentList $arguments -WindowStyle Hidden -Wait
        exit 0  # 原始进程退出
    }
    catch {
        Write-Host "获取管理员权限失败: $_" -ForegroundColor Red
        Read-Host "按Enter退出"
        exit 1
    }
}

# 显示标题
# Clear-Host
# Write-Host @"
# ===================================================
#       ZeroTier 便携版身份管理工具
#       版本: 1.1.2
#       日期: 2025-04-10
# ===================================================
# "@ -ForegroundColor Cyan

# 获取脚本所在目录
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
# 获取根目录（当前目录的父目录）
$rootPath = Split-Path -Parent $scriptPath
$binPath = Join-Path -Path $rootPath -ChildPath "bin"
$dataPath = Join-Path -Path $rootPath -ChildPath "data"
$zerotierExe = Join-Path -Path $binPath -ChildPath "zerotier-one_x64.exe"

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

    # 创建networks.d子目录
    $networksDir = Join-Path -Path $dataPath -ChildPath "networks.d"
    if (-not (Test-Path $networksDir)) {
        New-Item -ItemType Directory -Path $networksDir -Force | Out-Null
    }
}

# 显示菜单
function Show-Menu {
    Clear-Host
    Write-Host @"
===================================================
      ZeroTier 便携版身份管理工具
      版本: $version
      日期: 2025-04-10
===================================================
"@ -ForegroundColor Cyan

    Write-Host "`n请选择操作:" -ForegroundColor Yellow
    Write-Host "1. 生成新的ZeroTier身份" -ForegroundColor Green
    Write-Host "2. 导入现有身份文件" -ForegroundColor Green
    Write-Host "3. 备份当前身份" -ForegroundColor Green
    Write-Host "4. 查看当前身份" -ForegroundColor Green
    Write-Host "5. 退出" -ForegroundColor Red

    $choice = Read-Host "`n请输入选择 (1-5) [默认:5]"
    # 如果用户没有输入，默认选择退出
    if ([string]::IsNullOrEmpty($choice)) {
        return "5"
    }
    return $choice
}

# 生成新的身份
function New-ZTIdentity {
    $identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
    $identityPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public"

    if (Test-Path $identityFile) {
        Write-Host "警告: 已存在身份文件 $identityFile" -ForegroundColor Yellow
        $confirm = Read-Host "是否覆盖现有身份? 这将导致节点ID改变! (Y/N)"

        if ($confirm -ne "Y" -and $confirm -ne "y") {
            Write-Host "操作已取消" -ForegroundColor Red
            return
        }

        # 备份现有身份
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = Join-Path -Path $dataPath -ChildPath "identity.secret.bak-$timestamp"
        $backupPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public.bak-$timestamp"

        Copy-Item -Path $identityFile -Destination $backupFile -Force
        Copy-Item -Path $identityPublicFile -Destination $backupPublicFile -Force -ErrorAction SilentlyContinue

        Write-Host "已备份现有身份到: $backupFile" -ForegroundColor Green
    }

    Write-Host "正在生成新的身份..." -ForegroundColor Yellow
    $createIdCmd = "$zerotierExe -i generate `"$identityFile`""

    try {
        Invoke-Expression $createIdCmd | Out-Null
        Write-Host "身份文件已生成: $identityFile" -ForegroundColor Green

        # 显示身份信息
        if (Test-Path $identityPublicFile) {
            $publicKeyContent = Get-Content -Path $identityPublicFile -Raw
            $nodeId = $publicKeyContent.Substring(0, 10)  # 取前10个字符作为节点ID
            Write-Host "公钥文件: $identityPublicFile" -ForegroundColor Yellow
            Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
        }
        else {
            # 如果公钥文件不存在，则生成公钥文件
            Write-Host "正在从私钥生成公钥..." -ForegroundColor Yellow
            $generatePublicCmd = "$zerotierExe -i getpublic `"$identityFile`" > `"$identityPublicFile`""
            Invoke-Expression $generatePublicCmd

            # 检查生成是否成功
            if (Test-Path $identityPublicFile) {
                $publicKeyContent = Get-Content -Path $identityPublicFile -Raw
                $nodeId = $publicKeyContent.Substring(0, 10)  # 取前10个字符作为节点ID
                Write-Host "公钥文件已生成" -ForegroundColor Green
                Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
            }
            else {
                Write-Host "警告: 无法生成公钥文件" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "生成身份文件失败: $_" -ForegroundColor Red
    }
}

# 导入现有身份
function Import-ZTIdentity {
    $identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
    $identityPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public"

    # 检查是否已有身份文件
    if (Test-Path $identityFile) {
        Write-Host "警告: 已存在身份文件 $identityFile" -ForegroundColor Yellow
        $confirm = Read-Host "是否覆盖现有身份? (Y/N)"

        if ($confirm -eq "q" -or $confirm -eq "Q") {
            Write-Host "操作已取消，返回主菜单..." -ForegroundColor Yellow
            return
        }

        if ($confirm -ne "Y" -and $confirm -ne "y") {
            Write-Host "操作已取消" -ForegroundColor Red
            return
        }

        # 备份现有身份
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = Join-Path -Path $dataPath -ChildPath "identity.secret.bak-$timestamp"
        $backupPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public.bak-$timestamp"

        Copy-Item -Path $identityFile -Destination $backupFile -Force
        Copy-Item -Path $identityPublicFile -Destination $backupPublicFile -Force -ErrorAction SilentlyContinue

        Write-Host "已备份现有身份到: $backupFile" -ForegroundColor Green
    }

    # 提示用户提供导入文件路径，添加q选项和Esc键支持
    Write-Host "`n请输入要导入的身份文件(.secret)的完整路径" -ForegroundColor Green
    Write-Host "(输入'q'并按Enter返回主菜单，或按'Esc'键立即返回)" -ForegroundColor Yellow

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
    $importPath = Read-InputWithEsc

    # 检查是否按了ESC键或输入了q
    if ($importPath -eq "ESC" -or $importPath -eq "q" -or $importPath -eq "Q") {
        Write-Host "`n操作已取消，返回主菜单..." -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $importPath)) {
        Write-Host "错误: 文件不存在: $importPath" -ForegroundColor Red
        Write-Host "按任意键返回主菜单..." -ForegroundColor Yellow
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        return
    }

    try {
        # 复制文件到数据目录
        Copy-Item -Path $importPath -Destination $identityFile -Force
        Write-Host "身份文件已导入: $identityFile" -ForegroundColor Green

        # 生成公钥文件
        Write-Host "正在从私钥生成公钥..." -ForegroundColor Yellow
        $generatePublicCmd = "$zerotierExe -i getpublicidentity `"$identityFile`" > `"$identityPublicFile`""
        Invoke-Expression $generatePublicCmd

        if (Test-Path $identityPublicFile) {
            $publicKeyContent = Get-Content -Path $identityPublicFile -Raw
            $nodeId = $publicKeyContent.Substring(0, 10)  # 取前10个字符作为节点ID
            Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
        }
        else {
            Write-Host "警告: 无法生成公钥文件" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "导入身份文件失败: $_" -ForegroundColor Red
    }
}

# 备份当前身份
function Backup-ZTIdentity {
    $identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
    $identityPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public"

    if (-not (Test-Path $identityFile)) {
        Write-Host "错误: 没有找到身份文件: $identityFile" -ForegroundColor Red
        return
    }

    # 生成时间戳
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

    # 提示用户备份位置
    Write-Host "请选择备份位置:" -ForegroundColor Yellow
    Write-Host "1. 数据目录内备份" -ForegroundColor Green
    Write-Host "2. 选择其他位置备份" -ForegroundColor Green

    $backupChoice = Read-Host "请输入选择 (1-2)"

    $backupDir = ""
    if ($backupChoice -eq "1") {
        $backupDir = $dataPath
    }
    else {
        $backupDir = Read-Host "请输入备份目标文件夹的完整路径"

        if (-not (Test-Path $backupDir)) {
            $createDir = Read-Host "目录不存在，是否创建? (Y/N)"
            if ($createDir -eq "Y" -or $createDir -eq "y") {
                try {
                    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
                }
                catch {
                    Write-Host "创建目录失败: $_" -ForegroundColor Red
                    return
                }
            }
            else {
                Write-Host "操作已取消" -ForegroundColor Red
                return
            }
        }
    }

    # 设置备份文件路径
    $backupFile = Join-Path -Path $backupDir -ChildPath "zt-identity-backup-$timestamp.secret"
    $backupPublicFile = Join-Path -Path $backupDir -ChildPath "zt-identity-backup-$timestamp.public"

    try {
        # 复制文件到备份位置
        Copy-Item -Path $identityFile -Destination $backupFile -Force

        if (Test-Path $identityPublicFile) {
            Copy-Item -Path $identityPublicFile -Destination $backupPublicFile -Force
        }

        Write-Host "身份已成功备份到:" -ForegroundColor Green
        Write-Host "私钥: $backupFile" -ForegroundColor Green
        Write-Host "公钥: $backupPublicFile" -ForegroundColor Green
    }
    catch {
        Write-Host "备份身份文件失败: $_" -ForegroundColor Red
    }
}

# 查看当前身份
function Show-ZTIdentity {
    $identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
    $identityPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public"

    if (-not (Test-Path $identityFile)) {
        Write-Host "错误: 没有找到身份文件: $identityFile" -ForegroundColor Red
        return
    }

    Write-Host "当前ZeroTier身份信息:" -ForegroundColor Cyan
    Write-Host "私钥文件: $identityFile" -ForegroundColor Yellow

    if (Test-Path $identityPublicFile) {
        $publicKeyContent = Get-Content -Path $identityPublicFile -Raw
        $nodeId = $publicKeyContent.Substring(0, 10)  # 取前10个字符作为节点ID
        Write-Host "公钥文件: $identityPublicFile" -ForegroundColor Yellow
        Write-Host "节点ID: $nodeId" -ForegroundColor Green

        # 显示节点ID二维码（可选，如果需要更容易在移动设备上输入）
        # 此处可以添加生成二维码的逻辑，但需要额外的PowerShell模块或外部工具
    }
    else {
        Write-Host "警告: 未找到公钥文件，正在从私钥生成..." -ForegroundColor Yellow
        $generatePublicCmd = "$zerotierExe -i getpublicidentity `"$identityFile`" > `"$identityPublicFile`""

        try {
            Invoke-Expression $generatePublicCmd

            if (Test-Path $identityPublicFile) {
                $publicKeyContent = Get-Content -Path $identityPublicFile -Raw
                $nodeId = $publicKeyContent.Substring(0, 10)  # 取前10个字符作为节点ID
                Write-Host "公钥文件: $identityPublicFile" -ForegroundColor Yellow
                Write-Host "节点ID: $nodeId" -ForegroundColor Green
            }
            else {
                Write-Host "警告: 无法生成公钥文件" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "生成公钥文件失败: $_" -ForegroundColor Red
        }
    }
}

# 主循环
do {
    $choice = Show-Menu

    switch ($choice) {
        "1" {
            Clear-Host
            Write-Host "===== 生成新的ZeroTier身份 =====" -ForegroundColor Cyan
            New-ZTIdentity
        }
        "2" {
            Clear-Host
            Write-Host "===== 导入现有身份文件 =====" -ForegroundColor Cyan
            Import-ZTIdentity
        }
        "3" {
            Clear-Host
            Write-Host "===== 备份当前身份 =====" -ForegroundColor Cyan
            Backup-ZTIdentity
        }
        "4" {
            Clear-Host
            Write-Host "===== 查看当前身份 =====" -ForegroundColor Cyan
            Show-ZTIdentity
        }
        "5" {
            Write-Host "退出程序" -ForegroundColor Yellow
            exit 0  # 明确使用退出代码0，确保干净退出
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