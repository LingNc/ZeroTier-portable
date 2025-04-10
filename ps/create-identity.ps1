# ZeroTier便携版身份管理脚本
# 此脚本用于生成、备份和导入ZeroTier身份
# 作者: GitHub Copilot
# 版本: 1.0.0
# 日期: 2025-04-10

# 需要管理员权限
#Requires -RunAsAdministrator

# 检查是否有auto参数
param (
    [switch]$auto = $false
)

# 显示标题
Write-Host @"
===================================================
      ZeroTier 便携版身份管理工具
      版本: 1.0.0
      日期: 2025-04-10
===================================================
"@ -ForegroundColor Cyan

# 获取脚本所在目录
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
# 获取根目录（当前目录的父目录）
$rootPath = Split-Path -Parent $scriptPath
$binPath = Join-Path -Path $rootPath -ChildPath "bin"
$dataPath = Join-Path -Path $rootPath -ChildPath "data"
$planetReplacePs1 = Join-Path -Path $scriptPath -ChildPath "planet-replace.ps1"
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
    Write-Host "`n请选择操作:" -ForegroundColor Yellow
    Write-Host "1. 生成新的ZeroTier身份" -ForegroundColor Green
    Write-Host "2. 导入现有身份文件" -ForegroundColor Green
    Write-Host "3. 备份当前身份" -ForegroundColor Green
    Write-Host "4. 查看当前身份" -ForegroundColor Green
    Write-Host "5. 退出" -ForegroundColor Red

    $choice = Read-Host "`n请输入选择 (1-5)"
    return $choice
}

# 生成新的身份
function New-ZTIdentity {
    $identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
    $identityPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public"
    $isNewIdentity = $false

    if (Test-Path $identityFile) {
        if (-not $auto) {
            Write-Host "警告: 已存在身份文件 $identityFile" -ForegroundColor Yellow
            $confirm = Read-Host "是否覆盖现有身份? 这将导致节点ID改变! (Y/N)"

            if ($confirm -ne "Y" -and $confirm -ne "y") {
                Write-Host "操作已取消" -ForegroundColor Red
                return $false
            }
        } else {
            # 在auto模式下，如果已存在身份，则不覆盖
            Write-Host "在自动模式下检测到现有身份，将使用现有身份继续。" -ForegroundColor Yellow
            Show-ZTIdentity
            return $false
        }

        # 备份现有身份
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = Join-Path -Path $dataPath -ChildPath "identity.secret.bak-$timestamp"
        $backupPublicFile = Join-Path -Path $dataPath -ChildPath "identity.public.bak-$timestamp"

        Copy-Item -Path $identityFile -Destination $backupFile -Force
        Copy-Item -Path $identityPublicFile -Destination $backupPublicFile -Force -ErrorAction SilentlyContinue

        Write-Host "已备份现有身份到: $backupFile" -ForegroundColor Green
    } else {
        $isNewIdentity = $true
    }

    Write-Host "正在生成新的身份..." -ForegroundColor Yellow
    $createIdCmd = "$zerotierExe -i generate `"$identityFile`""

    try {
        Invoke-Expression $createIdCmd | Out-Null
        Write-Host "身份文件已生成: $identityFile" -ForegroundColor Green

        # 显示身份信息
        if (Test-Path $identityPublicFile) {
            $nodeId = Get-Content -Path $identityPublicFile -Raw
            Write-Host "节点ID: $nodeId" -ForegroundColor Cyan
        }

        return $isNewIdentity
    }
    catch {
        Write-Host "生成身份文件失败: $_" -ForegroundColor Red
        return $false
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

    # 提示用户提供导入文件路径
    $importPath = Read-Host "请输入要导入的身份文件(.secret)的完整路径"

    if (-not (Test-Path $importPath)) {
        Write-Host "错误: 文件不存在: $importPath" -ForegroundColor Red
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
            $nodeId = Get-Content -Path $identityPublicFile -Raw
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
        $nodeId = Get-Content -Path $identityPublicFile -Raw
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
                $nodeId = Get-Content -Path $identityPublicFile -Raw
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

# 运行Planet替换功能
function Start-PlanetReplace {
    # 检查planet-replace.ps1是否存在
    if (-not (Test-Path $planetReplacePs1)) {
        Write-Host "错误：无法找到Planet替换脚本: $planetReplacePs1" -ForegroundColor Red
        Write-Host "将使用默认Planet服务器继续..." -ForegroundColor Yellow
        return
    }

    # 启动Planet替换脚本
    Write-Host "`n启动Planet替换脚本，请按提示操作..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$planetReplacePs1`"" -Wait -NoNewWindow
    Write-Host "Planet配置已完成，继续启动过程..." -ForegroundColor Green
}

# 处理自动模式
if ($auto) {
    Write-Host "自动模式：检查身份状态并进行必要操作..." -ForegroundColor Cyan
    $identityFile = Join-Path -Path $dataPath -ChildPath "identity.secret"
    $isNewIdentity = $false

    if (-not (Test-Path $identityFile)) {
        Write-Host "未找到身份文件，自动生成新身份..." -ForegroundColor Yellow
        $isNewIdentity = New-ZTIdentity

        if ($isNewIdentity) {
            # 新生成的身份，询问是否配置Planet
            Write-Host "`n检测到新生成的身份，您可能需要配置自定义Planet服务器。" -ForegroundColor Yellow
            $replacePlanet = Read-Host "是否需要配置自定义Planet服务器? (Y/N)"

            if ($replacePlanet -eq "Y" -or $replacePlanet -eq "y") {
                Start-PlanetReplace
            }
        }
    } else {
        Write-Host "已存在身份文件，正在检查身份信息..." -ForegroundColor Green
        Show-ZTIdentity

        # 询问是否需要管理Planet
        $managePlanet = Read-Host "`n是否需要管理Planet配置? (Y/N)"
        if ($managePlanet -eq "Y" -or $managePlanet -eq "y") {
            Start-PlanetReplace
        }
    }

    # 自动模式下结束前的提示
    Write-Host "`n身份管理操作已完成，您可以继续使用ZeroTier。" -ForegroundColor Green
    Read-Host "按Enter键继续..."
    exit 0
}

# 主循环 (非自动模式)
do {
    $choice = Show-Menu

    switch ($choice) {
        "1" {
            $isNewIdentity = New-ZTIdentity
            if ($isNewIdentity) {
                Write-Host "`n检测到新生成的身份，您可能需要配置自定义Planet服务器。" -ForegroundColor Yellow
                $replacePlanet = Read-Host "是否需要配置自定义Planet服务器? (Y/N)"

                if ($replacePlanet -eq "Y" -or $replacePlanet -eq "y") {
                    Start-PlanetReplace
                }
            }
        }
        "2" { Import-ZTIdentity }
        "3" { Backup-ZTIdentity }
        "4" { Show-ZTIdentity }
        "5" { Write-Host "退出程序" -ForegroundColor Yellow; exit }
        default { Write-Host "无效选择，请重试" -ForegroundColor Red }
    }

    # 在每个操作完成后暂停
    if ($choice -ne "5") {
        Read-Host "`n按Enter继续..."
    }

} while ($choice -ne "5")