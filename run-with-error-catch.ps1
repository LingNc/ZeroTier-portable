# ZeroTier便携版EXE错误捕获启动脚本
# 用于防止EXE闪退看不到错误信息
# 作者: GitHub Copilot

# 启用错误捕获
$ErrorActionPreference = "Continue"

# 设置窗口标题
$host.UI.RawUI.WindowTitle = "ZeroTier便携版 - 错误捕获模式"

# 获取EXE路径
$exePath = Join-Path $PSScriptRoot "ZeroTier-portable.exe"

# 检查EXE是否存在
if (-not (Test-Path $exePath)) {
    Write-Host "错误: 未找到可执行文件: $exePath" -ForegroundColor Red
    Write-Host "请确保本脚本与ZeroTier-portable.exe位于同一目录。" -ForegroundColor Yellow
    Write-Host "按任意键退出..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

Write-Host "===== ZeroTier便携版错误捕获启动 =====" -ForegroundColor Cyan
Write-Host "当前时间: $(Get-Date)" -ForegroundColor Cyan
Write-Host "可执行文件: $exePath" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "正在启动ZeroTier便携版..." -ForegroundColor Green

# 创建进程对象
try {
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $exePath
    $startInfo.WorkingDirectory = $PSScriptRoot
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true

    # 创建进程并启动
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    $process.EnableRaisingEvents = $true

    # 为进程退出设置事件
    $exitEvent = Register-ObjectEvent -InputObject $process -EventName "Exited" -Action {
        $Global:processDone = $true
    }

    # 为输出和错误设置事件处理器
    $outputEvent = Register-ObjectEvent -InputObject $process -EventName "OutputDataReceived" -Action {
        if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
            Write-Host $EventArgs.Data
        }
    }

    $errorEvent = Register-ObjectEvent -InputObject $process -EventName "ErrorDataReceived" -Action {
        if (-not [string]::IsNullOrEmpty($EventArgs.Data)) {
            Write-Host $EventArgs.Data -ForegroundColor Red
        }
    }

    # 启动进程
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    # 等待进程完成
    $Global:processDone = $false
    while (-not $Global:processDone) {
        Start-Sleep -Milliseconds 100
    }

    # 清理事件处理器
    Unregister-Event -SourceIdentifier $outputEvent.Name
    Unregister-Event -SourceIdentifier $errorEvent.Name
    Unregister-Event -SourceIdentifier $exitEvent.Name

    # 显示进程结束状态
    if ($process.ExitCode -ne 0) {
        Write-Host "`n程序异常退出，退出代码: $($process.ExitCode)" -ForegroundColor Red

        Write-Host "`n===== 可能的错误原因 =====" -ForegroundColor Yellow
        Write-Host "1. 缺少必要的文件" -ForegroundColor Yellow
        Write-Host "2. 权限不足 (尝试以管理员身份运行)" -ForegroundColor Yellow
        Write-Host "3. 路径包含特殊字符" -ForegroundColor Yellow
        Write-Host "4. 临时目录无法访问" -ForegroundColor Yellow
        Write-Host "5. 嵌入文件解压失败" -ForegroundColor Yellow
        Write-Host "============================" -ForegroundColor Yellow
    } else {
        Write-Host "`n程序正常退出，退出代码: $($process.ExitCode)" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n启动过程中发生错误: $_" -ForegroundColor Red
}
finally {
    Write-Host "`n按任意键退出..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# PowerShell错误捕获包装器
# 用于执行命令并捕获错误
param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

try {
    # 将命令字符串拆分为数组，使用分号作为分隔符
    $commands = $Command -split ";"

    # 依次执行每个命令
    foreach ($cmd in $commands) {
        if (-not [string]::IsNullOrWhiteSpace($cmd)) {
            Write-Host "执行命令: $cmd" -ForegroundColor Yellow
            Invoke-Expression $cmd

            # 检查命令执行结果
            if ($LASTEXITCODE -ne 0) {
                throw "命令执行失败，错误代码: $LASTEXITCODE"
            }
        }
    }

    exit 0
}
catch {
    Write-Host "错误: $_" -ForegroundColor Red
    exit 1
}