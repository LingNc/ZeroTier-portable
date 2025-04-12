# 为ZeroTier便携版EXE添加数字签名
# 此脚本用于减少安全软件的误报
# 作者: LingNc

# 检查是否具有管理员权限
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "需要管理员权限运行此脚本。请以管理员身份重新运行。" -ForegroundColor Red
    exit 1
}

# 设置EXE路径
$rootPath = Split-Path -Parent $PSScriptRoot
$exePath = Join-Path $rootPath "ZeroTier-portable.exe"

# 检查EXE是否存在
if (-not (Test-Path $exePath)) {
    Write-Host "错误: 无法找到EXE文件: $exePath" -ForegroundColor Red
    exit 1
}

Write-Host "===== ZeroTier便携版EXE签名工具 =====" -ForegroundColor Cyan
Write-Host "此工具将帮助您为EXE添加数字签名，减少安全软件误报" -ForegroundColor Cyan
Write-Host "EXE文件: $exePath" -ForegroundColor Yellow

# 检查是否安装了证书
$certs = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert
if ($certs.Count -eq 0) {
    Write-Host "`n没有找到代码签名证书。您可以选择:" -ForegroundColor Yellow
    Write-Host "1. 创建自签名证书（仅适用于个人使用）" -ForegroundColor Yellow
    Write-Host "2. 退出并获取商业代码签名证书" -ForegroundColor Yellow

    $option = Read-Host "请选择 (1/2) [默认: 1]"
    if ($option -eq "2") {
        Write-Host "`n您可以从以下提供商获取代码签名证书:" -ForegroundColor Cyan
        Write-Host "- Sectigo (https://sectigo.com/)" -ForegroundColor Cyan
        Write-Host "- DigiCert (https://www.digicert.com/)" -ForegroundColor Cyan
        Write-Host "- GlobalSign (https://www.globalsign.com/)" -ForegroundColor Cyan
        Write-Host "获取证书后，重新运行此脚本。" -ForegroundColor Cyan
        exit 0
    }

    # 创建自签名证书
    Write-Host "`n正在创建自签名证书..." -ForegroundColor Yellow
    $certName = "ZeroTier便携版自签名证书"
    $cert = New-SelfSignedCertificate -Subject "CN=$certName" -CertStoreLocation Cert:\CurrentUser\My `
                                     -Type CodeSigningCert -KeyUsage DigitalSignature `
                                     -KeyAlgorithm RSA -KeyLength 2048 `
                                     -NotAfter (Get-Date).AddYears(5)

    Write-Host "已创建自签名证书: $($cert.Thumbprint)" -ForegroundColor Green
    Write-Host "注意: 自签名证书不会被Windows信任，但可以减少某些安全软件的误报" -ForegroundColor Yellow

    # 将证书添加到受信任的根证书颁发机构
    Write-Host "`n要使自签名证书在本机受信任，需要将其添加到受信任的根证书颁发机构" -ForegroundColor Yellow
    $addToRoot = Read-Host "是否将证书添加到受信任的根证书颁发机构? (Y/N) [默认: Y]"
    if ($addToRoot -ne "N" -and $addToRoot -ne "n") {
        $rootStore = New-Object System.Security.Cryptography.X509Certificates.X509Store -ArgumentList Root, LocalMachine
        $rootStore.Open("ReadWrite")
        $rootStore.Add($cert)
        $rootStore.Close()
        Write-Host "证书已添加到受信任的根证书颁发机构" -ForegroundColor Green
    }
} else {
    Write-Host "`n找到以下代码签名证书:" -ForegroundColor Green
    for ($i=0; $i -lt $certs.Count; $i++) {
        Write-Host "[$i] $($certs[$i].Subject) (到期时间: $($certs[$i].NotAfter))" -ForegroundColor Yellow
    }

    $certIndex = Read-Host "`n请选择要使用的证书编号 [默认: 0]"
    if ([string]::IsNullOrEmpty($certIndex)) { $certIndex = 0 }

    if ($certIndex -ge 0 -and $certIndex -lt $certs.Count) {
        $cert = $certs[$certIndex]
        Write-Host "已选择证书: $($cert.Subject)" -ForegroundColor Green
    } else {
        Write-Host "无效的选择，将使用第一个证书" -ForegroundColor Red
        $cert = $certs[0]
    }
}

# 使用SignTool对EXE进行签名
Write-Host "`n正在对EXE文件进行签名..." -ForegroundColor Yellow

# 检查是否已安装Windows SDK（包含SignTool）
$signToolPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x64\signtool.exe",
    "${env:ProgramFiles(x86)}\Windows Kits\10\bin\x86\signtool.exe",
    "${env:ProgramFiles}\Windows Kits\10\bin\x64\signtool.exe",
    "${env:ProgramFiles}\Windows Kits\10\bin\x86\signtool.exe",
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22000.0\x64\signtool.exe"  # 示例特定版本路径
)

$signTool = $null
foreach ($path in $signToolPaths) {
    if (Test-Path $path) {
        $signTool = $path
        break
    }
}

if (-not $signTool) {
    Write-Host "错误: 无法找到SignTool工具，请安装Windows SDK" -ForegroundColor Red
    Write-Host "您可以从Microsoft下载中心获取Windows SDK: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/" -ForegroundColor Yellow
    exit 1
}

Write-Host "找到SignTool: $signTool" -ForegroundColor Green

# 执行签名
try {
    # 添加时间戳服务器以确保签名长期有效
    $timestampServer = "http://timestamp.digicert.com"
    $description = "ZeroTier便携版"

    # 使用SignTool签名
    $signArgs = @(
        "sign",
        "/f", "CERT:\CurrentUser\My\$($cert.Thumbprint)",
        "/d", "`"$description`"",
        "/t", $timestampServer,
        "`"$exePath`""
    )

    Write-Host "执行命令: $signTool $($signArgs -join ' ')" -ForegroundColor Gray
    & $signTool $signArgs

    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ EXE文件签名成功!" -ForegroundColor Green

        # 验证签名
        Write-Host "`n正在验证签名..." -ForegroundColor Yellow
        $verifyArgs = @("verify", "/pa", "`"$exePath`"")
        & $signTool $verifyArgs

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 签名验证成功!" -ForegroundColor Green
            Write-Host "`n签名后的EXE可能会减少安全软件的误报。" -ForegroundColor Cyan
            Write-Host "如果仍然出现误报，可以考虑向安全软件厂商提交误报报告。" -ForegroundColor Cyan
        } else {
            Write-Host "⚠️ 签名验证失败，但文件已签名。可能是证书不受信任。" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ EXE文件签名失败!" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ 签名过程中出错: $_" -ForegroundColor Red
}

# 等待用户确认
Write-Host "`n按任意键退出..." -ForegroundColor Gray
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")