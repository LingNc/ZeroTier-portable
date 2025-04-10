# ZeroTier便携版打包脚本
# 通过配置文件自动打包EXE
# 作者: LingNc

# 设置编码为UTF8，确保正确处理中文
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 获取脚本所在目录
$scriptPath = $PSScriptRoot
if (!$scriptPath) { $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path }

# 配置文件路径
$configFile = Join-Path $scriptPath "ps2exe.config.json"

# 检查配置文件是否存在
if (-not (Test-Path $configFile)) {
    Write-Host "错误: 找不到配置文件 $configFile" -ForegroundColor Red
    exit 1
}

# 读取配置文件
try {
    $config = Get-Content $configFile -Raw | ConvertFrom-Json
    Write-Host "已成功读取配置文件" -ForegroundColor Green
}
catch {
    Write-Host "错误: 无法解析配置文件: $_" -ForegroundColor Red
    exit 1
}

# 检查是否安装了ps2exe模块
$ps2exeModule = Get-Module -ListAvailable -Name ps2exe
if (-not $ps2exeModule) {
    Write-Host "正在安装ps2exe模块..." -ForegroundColor Yellow
    try {
        Install-Module -Name ps2exe -Scope CurrentUser -Force
        Write-Host "ps2exe模块安装成功" -ForegroundColor Green
    }
    catch {
        Write-Host "错误: 无法安装ps2exe模块: $_" -ForegroundColor Red
        Write-Host "请手动安装模块: Install-Module -Name ps2exe -Scope CurrentUser -Force" -ForegroundColor Yellow
        exit 1
    }
}

# 确保bin和ps目录与main.ps1在同一位置
Write-Host "检查必要的文件和目录..." -ForegroundColor Yellow
$binDir = Join-Path $scriptPath "bin"
$psDir = Join-Path $scriptPath "ps"

if (-not (Test-Path $binDir -PathType Container)) {
    Write-Host "错误: 找不到bin目录: $binDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $psDir -PathType Container)) {
    Write-Host "错误: 找不到ps目录: $psDir" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 检查完成，所有必要文件已找到" -ForegroundColor Green

# 准备ps2exe参数
$inputFile = Join-Path $scriptPath $config.inputFile
$outputFile = Join-Path $scriptPath $config.outputFile

# 构建基本命令
$ps2exeParams = @(
    "-InputFile `"$inputFile`""
    "-OutputFile `"$outputFile`""
)

# 添加版本信息参数
if ($config.versionInfo) {
    $versionInfo = $config.versionInfo

    # 基本版本号参数
    if ($versionInfo.fileVersion) {
        $ps2exeParams += "-Version `"$($versionInfo.fileVersion)`""
    }

    # 其他元数据参数
    if ($versionInfo.company) {
        $ps2exeParams += "-Company `"$($versionInfo.company)`""
    }
    if ($versionInfo.product) {
        $ps2exeParams += "-Product `"$($versionInfo.product)`""
    }
    if ($versionInfo.description) {
        $ps2exeParams += "-Description `"$($versionInfo.description)`""
    }
    if ($versionInfo.copyright) {
        $ps2exeParams += "-Copyright `"$($versionInfo.copyright)`""
    }
    if ($versionInfo.trademark) {
        $ps2exeParams += "-Trademark `"$($versionInfo.trademark)`""
    }
}

# 添加选项参数
if ($config.options) {
    $options = $config.options

    if ($options.requireAdmin -eq $true) {
        $ps2exeParams += "-requireAdmin"
    }

    if ($options.PSObject.Properties['noConsole']) {
        $ps2exeParams += "-NoConsole:`$$($options.noConsole.ToString().ToLower())"
    }

    if ($options.supportOS -eq $true) {
        $ps2exeParams += "-supportOS"
    }

    if ($options.DPIAware -eq $true) {
        $ps2exeParams += "-DPIAware"
    }
}

# 重要提示: 不使用include参数，依赖文件将通过main.ps1中的逻辑处理
Write-Host "注意: 将使用脚本内部逻辑处理依赖文件，不使用include参数" -ForegroundColor Yellow

# 构建完整命令
$ps2exeCommand = "ps2exe " + ($ps2exeParams -join " ")

# 显示命令
Write-Host "`n将执行以下命令:" -ForegroundColor Cyan
Write-Host $ps2exeCommand -ForegroundColor Yellow

# 询问用户是否继续
$continue = Read-Host "`n是否继续执行? (Y/N) [默认: Y]"
if ($continue -eq "N" -or $continue -eq "n") {
    Write-Host "操作已取消" -ForegroundColor Yellow
    exit 0
}

# 执行命令
Write-Host "`n正在打包..." -ForegroundColor Cyan
try {
    # 执行PS2EXE命令
    $result = Invoke-Expression $ps2exeCommand

    # 检查结果
    if ($result -match "Output file .* written") {
        Write-Host "`n✅ 打包成功!" -ForegroundColor Green
        Write-Host "输出文件: $outputFile" -ForegroundColor Green

        # 显示文件信息
        $fileInfo = Get-Item $outputFile
        Write-Host "文件大小: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green

        # 解释给用户
        Write-Host "`n注意：由于无法使用include参数，exe中没有包含依赖文件" -ForegroundColor Yellow
        Write-Host "您需要确保以下文件/目录与生成的EXE位于同一目录下:" -ForegroundColor Yellow
        Write-Host "  - bin/ 目录 (包含主程序和命令行工具)" -ForegroundColor Yellow
        Write-Host "  - ps/ 目录 (包含辅助脚本)" -ForegroundColor Yellow
        Write-Host "运行时它们会被自动复制到临时目录中使用" -ForegroundColor Yellow
    }
    else {
        Write-Host "`n❌ 打包可能未成功完成，请检查以上输出" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n❌ 打包过程中发生错误: $_" -ForegroundColor Red
}

Write-Host "`n打包过程完成" -ForegroundColor Cyan