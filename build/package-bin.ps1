# ZeroTier便携版目录打包脚本
# 将指定目录压缩并转换为Base64形式
# 作者: LingNc
# 版本: 1.2.0

# 参数定义
param (
    [string]$SourceDirectory = "bin",      # 要打包的目录，默认为bin
    [string]$OutputName = "",              # 输出文件名（不含扩展名）
    [switch]$Force = $false                # 强制覆盖现有文件
)

# 设置编码为UTF8，确保正确处理中文
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 获取脚本所在目录
$scriptPath = $PSScriptRoot
if (!$scriptPath) { $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path }

# 配置路径
$rootPath = Split-Path -Parent $scriptPath

# 自动生成输出名称（如果未指定）
if ([string]::IsNullOrEmpty($OutputName)) {
    $OutputName = $SourceDirectory.Replace("\", "-").Replace("/", "-")
}

# 构建源目录和输出目录路径
$sourcePath = Join-Path -Path $rootPath -ChildPath $SourceDirectory
$outputPath = Join-Path -Path $scriptPath -ChildPath "$OutputName-package"
$zipFile = Join-Path -Path $outputPath -ChildPath "$OutputName.zip"
$base64File = Join-Path -Path $outputPath -ChildPath "$OutputName.b64"
$extractCodeFile = Join-Path -Path $outputPath -ChildPath "extract-code.ps1"

# 检查源目录是否存在
if (-not (Test-Path $sourcePath -PathType Container)) {
    Write-Host "错误: 源目录不存在: $sourcePath" -ForegroundColor Red
    exit 1
}

# 检查输出目录是否存在，如果不存在则创建
if (Test-Path $outputPath) {
    if ($Force) {
        Write-Host "输出目录已存在，将被清空: $outputPath" -ForegroundColor Yellow
        Remove-Item -Path "$outputPath\*" -Recurse -Force
    }
    elseif ((Get-ChildItem -Path $outputPath -Force | Measure-Object).Count -gt 0) {
        Write-Host "警告: 输出目录不为空: $outputPath" -ForegroundColor Yellow
        $continue = Read-Host "是否继续并覆盖现有文件? (Y/N) [默认: N]"
        if ($continue -ne "Y" -and $continue -ne "y") {
            Write-Host "操作已取消" -ForegroundColor Yellow
            exit 0
        }
        Remove-Item -Path "$outputPath\*" -Recurse -Force
    }
} else {
    New-Item -Path $outputPath -ItemType Directory -Force | Out-Null
    Write-Host "已创建输出目录: $outputPath" -ForegroundColor Green
}

# 显示打包信息
Write-Host @"
===================================================
         ZeroTier便携版目录打包工具
         版本: 1.2.0
===================================================
"@ -ForegroundColor Cyan

Write-Host "源目录: $sourcePath" -ForegroundColor Yellow
Write-Host "输出路径: $outputPath" -ForegroundColor Yellow
Write-Host "打包名称: $OutputName" -ForegroundColor Yellow

# 计算文件总大小
$totalSize = 0
$fileCount = 0
Get-ChildItem -Path $sourcePath -Recurse -File | ForEach-Object {
    $totalSize += $_.Length
    $fileCount++
}

Write-Host "$SourceDirectory 目录包含 $fileCount 个文件，总大小: $([Math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Yellow

# 询问是否继续
$continue = Read-Host "`n是否开始打包? (Y/N) [默认: Y]"
if ($continue -eq "N" -or $continue -eq "n") {
    Write-Host "操作已取消" -ForegroundColor Yellow
    exit 0
}

# 开始打包流程
Write-Host "`n[1/4] 正在创建zip压缩包..." -ForegroundColor Cyan
try {
    # 检查可用的压缩工具
    $compressionMethod = "BuiltIn"
    $7zipPath = $null

    # 检查7-Zip是否存在
    $possiblePaths = @(
        # 首先检查本地build目录中的7z.exe
        (Join-Path $scriptPath "7z.exe"),
        # 然后检查其他可能的安装位置
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe",
        "${env:ProgramFiles}\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "${env:LOCALAPPDATA}\Programs\7-Zip\7z.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $7zipPath = $path
            $compressionMethod = "7-Zip"
            Write-Host "找到7-Zip: $7zipPath" -ForegroundColor Green
            break
        }
    }

    # 删除旧文件（如果存在）
    if (Test-Path $zipFile) {
        Remove-Item -Path $zipFile -Force
    }

    if (Test-Path $base64File) {
        Remove-Item -Path $base64File -Force
    }

    # 使用选择的压缩方法
    if ($compressionMethod -eq "7-Zip") {
        Write-Host "使用7-Zip进行高效压缩: $7zipPath" -ForegroundColor Green

        # 使用LZMA2算法和最高压缩级别
        $arguments = "a -t7z `"$zipFile`" `"$sourcePath\*`" -mx=9 -mmt=on -m0=LZMA2"
        Write-Host "执行: & `"$7zipPath`" $arguments" -ForegroundColor Gray

        $process = Start-Process -FilePath $7zipPath -ArgumentList $arguments -NoNewWindow -PassThru -Wait
        if ($process.ExitCode -ne 0) {
            throw "7-Zip返回错误代码: $($process.ExitCode)"
        }
    }
    else {
        Write-Host "使用内置压缩功能 (压缩率可能低于7-Zip)" -ForegroundColor Yellow

        # 使用内置Compress-Archive
        $compress = @{
            Path = "$sourcePath\*"
            DestinationPath = $zipFile
            CompressionLevel = "Optimal"
        }
        Compress-Archive @compress -Force
    }

    # 检查压缩文件是否创建成功
    if (Test-Path $zipFile) {
        $compressedSize = (Get-Item $zipFile).Length
        Write-Host "✅ 压缩成功: $zipFile ($([Math]::Round($compressedSize / 1MB, 2)) MB)" -ForegroundColor Green
        $compressionRatio = [Math]::Round(($totalSize - $compressedSize) / $totalSize * 100, 2)
        Write-Host "   压缩率: $compressionRatio% (原始大小的 $([Math]::Round($compressedSize / $totalSize * 100, 2))%)" -ForegroundColor Green
    }
    else {
        throw "压缩文件未创建"
    }
}
catch {
    Write-Host "❌ 创建压缩包失败: $_" -ForegroundColor Red
    exit 1
}

# 转换为Base64
Write-Host "`n[2/4] 正在将压缩文件转换为Base64编码..." -ForegroundColor Cyan
try {
    # 读取压缩文件并编码为Base64
    $bytes = [IO.File]::ReadAllBytes($zipFile)
    $base64String = [Convert]::ToBase64String($bytes)

    # 将Base64保存到文件
    [IO.File]::WriteAllText($base64File, $base64String)

    # 显示结果
    $base64Size = (Get-Item $base64File).Length
    Write-Host "✅ Base64转换成功: $base64File ($([Math]::Round($base64Size / 1MB, 2)) MB)" -ForegroundColor Green
    $overhead = [Math]::Round(($base64Size - $compressedSize) / $compressedSize * 100, 2)
    Write-Host "   Base64开销: +$overhead% (比压缩文件增大约 $overhead%)" -ForegroundColor Yellow
}
catch {
    Write-Host "❌ Base64转换失败: $_" -ForegroundColor Red
    exit 1
}

# 生成解压缩脚本
Write-Host "`n[3/4] 正在生成解压缩函数代码..." -ForegroundColor Cyan
try {
    # 生成函数名
    $extractFunctionName = "Extract-${OutputName}Package"

    # 注意这里使用双引号的字符串而不是here-string来避免转义问题
    $extractCode = "# ZeroTier便携版 $SourceDirectory 目录解压函数`r`n"
    $extractCode += "# 此段代码由package-bin.ps1自动生成`r`n"
    $extractCode += "# 生成时间: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")`r`n"
    $extractCode += "# 压缩方法: $compressionMethod`r`n"
    $extractCode += "# 原始大小: $([Math]::Round($totalSize / 1MB, 2)) MB`r`n"
    $extractCode += "# 压缩大小: $([Math]::Round($compressedSize / 1MB, 2)) MB`r`n`r`n"

    $extractCode += "function $extractFunctionName {`r`n"
    $extractCode += "    param (`r`n"
    $extractCode += "        [string]`$DestinationPath,`r`n"
    $extractCode += "        [switch]`$Force = `$false`r`n"
    $extractCode += "    )`r`n`r`n"

    $extractCode += "    Write-Host ""开始解压 $SourceDirectory 目录..."" -ForegroundColor Yellow`r`n`r`n"

    $extractCode += "    # 基本检查`r`n"
    $extractCode += "    if ([string]::IsNullOrEmpty(`$DestinationPath)) {`r`n"
    $extractCode += "        `$DestinationPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) ""ZeroTier-Portable-$SourceDirectory""`r`n"
    $extractCode += "        Write-Host ""未指定目标路径，使用默认临时目录: `$DestinationPath"" -ForegroundColor Yellow`r`n"
    $extractCode += "    }`r`n`r`n"

    $extractCode += "    # 如果目标目录已存在且不强制覆盖`r`n"
    $extractCode += "    if ((Test-Path `$DestinationPath) -and -not `$Force) {`r`n"
    $extractCode += "        Write-Host ""目标目录已存在。使用-Force参数覆盖现有文件。"" -ForegroundColor Yellow`r`n"
    $extractCode += "        return `$false`r`n"
    $extractCode += "    }`r`n`r`n"

    $extractCode += "    # 确保目标目录存在`r`n"
    $extractCode += "    if (-not (Test-Path `$DestinationPath -PathType Container)) {`r`n"
    $extractCode += "        New-Item -Path `$DestinationPath -ItemType Directory -Force | Out-Null`r`n"
    $extractCode += "        Write-Host ""创建目标目录: `$DestinationPath"" -ForegroundColor Gray`r`n"
    $extractCode += "    } elseif (`$Force) {`r`n"
    $extractCode += "        # 如果指定了强制覆盖，清空目录`r`n"
    $extractCode += "        Get-ChildItem -Path `$DestinationPath -Recurse | Remove-Item -Force -Recurse`r`n"
    $extractCode += "        Write-Host ""已清空目标目录，准备重新解压"" -ForegroundColor Gray`r`n"
    $extractCode += "    }`r`n`r`n"

    $extractCode += "    # 临时文件路径`r`n"
    $extractCode += "    `$tempArchive = Join-Path -Path ([System.IO.Path]::GetTempPath()) ""zt-$OutputName-temp-$(Get-Random).zip""`r`n`r`n"

    $extractCode += "    # 解压流程`r`n"
    $extractCode += "    try {`r`n"
    $extractCode += "        Write-Host ""正在将Base64解码为压缩文件..."" -ForegroundColor Gray`r`n`r`n"

    $extractCode += "        `$base64Content = @'`r`n$base64String`r`n'@`r`n`r`n"

    $extractCode += "        `$bytes = [Convert]::FromBase64String(`$base64Content)`r`n"
    $extractCode += "        [IO.File]::WriteAllBytes(`$tempArchive, `$bytes)`r`n`r`n"

    $extractCode += "        # 验证压缩文件是否创建`r`n"
    $extractCode += "        if (-not (Test-Path `$tempArchive)) {`r`n"
    $extractCode += "            throw ""无法创建临时压缩文件""`r`n"
    $extractCode += "        }`r`n`r`n"

    $extractCode += "        Write-Host ""成功创建临时压缩文件: `$tempArchive"" -ForegroundColor Gray`r`n"
    $extractCode += "    }`r`n"
    $extractCode += "    catch {`r`n"
    $extractCode += "        Write-Host ""Base64解码失败: `$_"" -ForegroundColor Red`r`n"
    $extractCode += "        return `$false`r`n"
    $extractCode += "    }`r`n`r`n"

    $extractCode += "    # 解压文件`r`n"
    $extractCode += "    try {`r`n"
    $extractCode += "        Write-Host ""正在解压缩文件到 `$DestinationPath..."" -ForegroundColor Gray`r`n`r`n"

    $extractCode += "        # 使用Expand-Archive解压`r`n"
    $extractCode += "        Expand-Archive -Path `$tempArchive -DestinationPath `$DestinationPath -Force`r`n`r`n"

    $extractCode += "        # 计算解压后的文件数量`r`n"
    $extractCode += "        `$extractedFiles = (Get-ChildItem -Path `$DestinationPath -Recurse -File).Count`r`n"
    $extractCode += "        Write-Host ""✓ 已成功解压 `$extractedFiles 个文件到 `$DestinationPath"" -ForegroundColor Green`r`n`r`n"

    # 添加目录特定的关键文件检查逻辑
    if ($SourceDirectory -eq "bin") {
        $extractCode += "        # 验证关键文件`r`n"
        $extractCode += "        `$zerotierExe = Join-Path `$DestinationPath ""zerotier-one_x64.exe""`r`n"
        $extractCode += "        if (Test-Path `$zerotierExe) {`r`n"
        $extractCode += "            Write-Host ""✓ 验证核心程序文件: `$((Get-Item `$zerotierExe).Name)"" -ForegroundColor Green`r`n"
        $extractCode += "        } else {`r`n"
        $extractCode += "            Write-Host ""警告: 未找到核心程序文件!"" -ForegroundColor Yellow`r`n"
        $extractCode += "        }`r`n`r`n"
    }
    elseif ($SourceDirectory -eq "ps") {
        $extractCode += "        # 验证关键文件`r`n"
        $extractCode += "        `$createIdentityPs1 = Join-Path `$DestinationPath ""create-identity.ps1""`r`n"
        $extractCode += "        `$planetReplacePs1 = Join-Path `$DestinationPath ""planet-replace.ps1""`r`n"
        $extractCode += "        if (Test-Path `$createIdentityPs1) {`r`n"
        $extractCode += "            Write-Host ""✓ 验证身份创建脚本文件"" -ForegroundColor Green`r`n"
        $extractCode += "        }`r`n"
        $extractCode += "        if (Test-Path `$planetReplacePs1) {`r`n"
        $extractCode += "            Write-Host ""✓ 验证Planet替换脚本文件"" -ForegroundColor Green`r`n"
        $extractCode += "        }`r`n`r`n"
    }
    else {
        $extractCode += "        # 检查解压是否成功`r`n"
        $extractCode += "        if (`$extractedFiles -gt 0) {`r`n"
        $extractCode += "            Write-Host ""✓ 文件解压成功"" -ForegroundColor Green`r`n"
        $extractCode += "        } else {`r`n"
        $extractCode += "            Write-Host ""警告: 未解压出任何文件!"" -ForegroundColor Yellow`r`n"
        $extractCode += "        }`r`n`r`n"
    }

    $extractCode += "        return `$true`r`n"
    $extractCode += "    }`r`n"
    $extractCode += "    catch {`r`n"
    $extractCode += "        Write-Host ""解压缩失败: `$_"" -ForegroundColor Red`r`n"
    $extractCode += "        return `$false`r`n"
    $extractCode += "    }`r`n"
    $extractCode += "    finally {`r`n"
    $extractCode += "        # 清理临时文件`r`n"
    $extractCode += "        if (Test-Path `$tempArchive) {`r`n"
    $extractCode += "            Remove-Item -Path `$tempArchive -Force -ErrorAction SilentlyContinue`r`n"
    $extractCode += "            Write-Host ""已清理临时压缩文件"" -ForegroundColor Gray`r`n"
    $extractCode += "        }`r`n"
    $extractCode += "    }`r`n"
    $extractCode += "}"

    # 使用UTF-8带BOM编码保存文件
    $utf8WithBomEncoding = New-Object System.Text.UTF8Encoding $true
    [IO.File]::WriteAllText($extractCodeFile, $extractCode, $utf8WithBomEncoding)

    Write-Host "✅ 解压函数代码已生成: $extractCodeFile (使用UTF-8带BOM编码)" -ForegroundColor Green
    Write-Host "   生成的函数名: $extractFunctionName" -ForegroundColor Green
}
catch {
    Write-Host "❌ 生成解压函数代码失败: $_" -ForegroundColor Red
    exit 1
}

# 总结
Write-Host "`n[4/4] 打包过程完成!" -ForegroundColor Cyan
Write-Host @"
===================================================
                  打包结果摘要
===================================================
源目录: $SourceDirectory
函数名称: $extractFunctionName
压缩方法: $compressionMethod
原始文件大小: $([Math]::Round($totalSize / 1MB, 2)) MB
压缩包大小: $([Math]::Round($compressedSize / 1MB, 2)) MB
Base64大小: $([Math]::Round($base64Size / 1MB, 2)) MB
压缩率: $compressionRatio%
===================================================

生成的文件:
1. $zipFile
2. $base64File
3. $extractCodeFile

后续操作:
将extract-code.ps1中的代码嵌入到main.ps1中，
main.ps1使用$extractFunctionName函数提取文件。
===================================================
"@ -ForegroundColor Green

# 显示与main.ps1集成的建议
Write-Host @"
在main.ps1中集成此打包的建议:

1. 将解压函数代码复制到main.ps1中
2. 当以EXE模式运行时:
   - 使用$extractFunctionName解压目录到TEMP路径
   - 更新路径变量指向解压的位置
3. 程序结束时清理临时文件

命令示例:
- 提取到临时目录: $extractFunctionName -DestinationPath "\`$runtimePath\\$SourceDirectory"
- 清理: Remove-Item -Path "\`$runtimePath" -Recurse -Force
"@ -ForegroundColor Cyan
