# ZeroTier便携版调试测试脚本
# 用于测试main.ps1的功能并详细显示错误信息
# 作者: LingNc

# 启用详细输出
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
$ErrorActionPreference = "Continue"

# 定义颜色函数，使输出更明显
function Write-ColorText {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Text,

        [Parameter(Mandatory=$false)]
        [ConsoleColor]$ForegroundColor = [ConsoleColor]::White
    )

    $originalColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    Write-Output $Text
    $host.UI.RawUI.ForegroundColor = $originalColor
}

# 显示开始测试信息
Write-ColorText "===== ZeroTier便携版脚本测试开始 =====" -ForegroundColor Cyan
Write-ColorText "当前时间: $(Get-Date)" -ForegroundColor Cyan
Write-ColorText "测试脚本: main.ps1" -ForegroundColor Cyan
Write-ColorText "=======================================" -ForegroundColor Cyan

# 获取脚本路径
$scriptPath = Join-Path $PSScriptRoot "main.ps1"
Write-ColorText "脚本路径: $scriptPath" -ForegroundColor Yellow

# 检查脚本是否存在
if (-not (Test-Path $scriptPath)) {
    Write-ColorText "错误: 找不到脚本文件 $scriptPath" -ForegroundColor Red
    exit 1
}

# 捕获所有错误
try {
    Write-ColorText "`n正在执行脚本..." -ForegroundColor Green

    # 创建一个新的PowerShell进程来执行脚本，并设置暂停选项
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = $PSScriptRoot

    $process = [System.Diagnostics.Process]::Start($psi)

    # 实时读取输出
    $outputReader = $process.StandardOutput
    $errorReader = $process.StandardError

    # 创建后台作业来读取输出
    $outputJob = Start-Job -ScriptBlock {
        param($reader)
        while (!$reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line) { $line }
        }
    } -ArgumentList $outputReader

    $errorJob = Start-Job -ScriptBlock {
        param($reader)
        while (!$reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ($line) { $line }
        }
    } -ArgumentList $errorReader

    # 显示输出
    while ($true) {
        $outputData = Receive-Job -Job $outputJob
        $errorData = Receive-Job -Job $errorJob

        if ($outputData) { Write-Host $outputData }
        if ($errorData) { Write-ColorText $errorData -ForegroundColor Red }

        if ($process.HasExited) {
            # 确保获取所有剩余输出
            $outputData = Receive-Job -Job $outputJob
            $errorData = Receive-Job -Job $errorJob

            if ($outputData) { Write-Host $outputData }
            if ($errorData) { Write-ColorText $errorData -ForegroundColor Red }

            break
        }

        Start-Sleep -Milliseconds 100
    }

    # 处理退出状态
    if ($process.ExitCode -eq 0) {
        Write-ColorText "`n脚本执行完成，退出代码: $($process.ExitCode)" -ForegroundColor Green
    } else {
        Write-ColorText "`n脚本执行失败，退出代码: $($process.ExitCode)" -ForegroundColor Red
    }
}
catch {
    Write-ColorText "`n测试过程中发生错误: $_" -ForegroundColor Red
    Write-ColorText $_.ScriptStackTrace -ForegroundColor Red
}
finally {
    Write-ColorText "`n===== 测试完成 =====`n" -ForegroundColor Cyan
    Write-ColorText "按任意键退出..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}