# ZeroTier便携版启动脚本
# 使用分号分隔命令以适应PowerShell语法
# 作者: LingNc

# 获取脚本所在目录
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildPath = Join-Path $scriptPath "build"

Write-Host "开始构建过程..." -ForegroundColor Cyan

try {
    # 切换到构建目录并执行build.ps1
    Push-Location $buildPath
    & powershell -ExecutionPolicy Bypass -File .\build.ps1
    if ($LASTEXITCODE -ne 0) {
        throw "构建失败，错误代码: $LASTEXITCODE"
    }
    Pop-Location

    Write-Host "构建完成" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "构建过程出错: $_" -ForegroundColor Red
    exit 1
}
finally {
    # 确保返回原始目录
    if ((Get-Location).Path -eq $buildPath) {
        Pop-Location
    }
}