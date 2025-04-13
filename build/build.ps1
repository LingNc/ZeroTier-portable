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
} else {
    Write-Host "已检测到ps2exe模块" -ForegroundColor Green
    # 显示版本信息
    $ps2exeVersion = (Get-Module -ListAvailable -Name ps2exe | Sort-Object Version -Descending | Select-Object -First 1).Version
    Write-Host "ps2exe模块版本: $ps2exeVersion" -ForegroundColor Green
}

# 确保必要的文件和目录存在
Write-Host "检查必要的文件和目录..." -ForegroundColor Yellow
$rootPath = Split-Path -Parent $scriptPath
$mainScript = Join-Path $rootPath $config.inputFile

if (-not (Test-Path $mainScript -PathType Leaf)) {
    Write-Host "错误: 找不到主脚本文件: $mainScript" -ForegroundColor Red
    exit 1
}

# 读取原始脚本内容
$originalContent = Get-Content $mainScript -Raw

# 处理文件压缩
function Process-Files {
    param(
        [string[]]$FilePaths,
        [string]$Method = "zip",
        [string]$TempDir = (Join-Path $env:TEMP "zt_packaging_$(Get-Random)")
    )

    Write-Host "正在处理文件: $($FilePaths -join ', ')" -ForegroundColor Yellow
    Write-Host "处理方式: $Method" -ForegroundColor Yellow

    try {
        # 创建临时目录
        New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

        # 收集所有匹配的文件
        $files = @()
        foreach ($pattern in $FilePaths) {
            $resolvedPath = Join-Path $rootPath $pattern.Replace('/**', '\*').Replace('**', '*')
            Write-Host "解析路径: $resolvedPath" -ForegroundColor Gray
            $matchingFiles = Get-ChildItem -Path $resolvedPath -Recurse -File
            $files += $matchingFiles
        }

        if ($files.Count -eq 0) {
            Write-Host "警告: 未找到匹配的文件" -ForegroundColor Yellow
            return $null
        }

        Write-Host "找到 $($files.Count) 个文件" -ForegroundColor Green

        # 根据方法处理文件
        if ($Method -eq "zip") {
            # ZIP压缩模式
            $tempFilesDir = Join-Path $TempDir "zerotier-portable"
            New-Item -Path $tempFilesDir -ItemType Directory -Force | Out-Null

            # 复制文件并保持相对路径
            foreach ($file in $files) {
                $relativePath = $file.FullName.Substring($rootPath.Length + 1)
                $destPath = Join-Path $tempFilesDir $relativePath
                $destDir = Split-Path -Parent $destPath

                # 确保目标目录存在
                if (-not (Test-Path $destDir)) {
                    New-Item -Path $destDir -ItemType Directory -Force | Out-Null
                }

                # 复制文件
                Copy-Item -Path $file.FullName -Destination $destPath -Force
            }

            # 压缩文件
            $zipFile = Join-Path $TempDir "package.zip"
            Compress-Archive -Path $tempFilesDir -DestinationPath $zipFile -Force

            # 转换为Base64
            $bytes = [System.IO.File]::ReadAllBytes($zipFile)
            $base64 = [Convert]::ToBase64String($bytes)

            return @{
                Type = "zip"
                Data = $base64
            }
        }
        else {
            # 直接Base64编码模式
            $fileDict = @{}
            foreach ($file in $files) {
                $relativePath = $file.FullName.Substring($rootPath.Length + 1).Replace('\', '/')
                $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
                $base64 = [Convert]::ToBase64String($bytes)
                $fileDict[$relativePath] = $base64
            }

            return @{
                Type = "direct"
                Data = $fileDict
            }
        }
    }
    catch {
        Write-Host "处理文件时出错: $_" -ForegroundColor Red
        return $null
    }
    finally {
        # 清理临时文件
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 复制文件并保持相对路径
function Copy-FilesWithStructure {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [string]$RootPath
    )

    $sourceItem = Get-Item -Path $SourcePath
    $relativePath = $sourceItem.FullName.Substring($RootPath.Length + 1).Replace('\', '/')

    if ($sourceItem.PSIsContainer) {
        $null = New-Item -ItemType Directory -Path $DestinationPath -Force
        Get-ChildItem -Path $SourcePath | ForEach-Object {
            Copy-FilesWithStructure -SourcePath $_.FullName -DestinationPath (Join-Path $DestinationPath $_.Name) -RootPath $RootPath
        }
    }
    else {
        $destDir = Split-Path -Parent $DestinationPath
        if (-not (Test-Path $destDir)) {
            $null = New-Item -ItemType Directory -Path $destDir -Force
        }
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
    }

    return $relativePath
}

# 处理文件打包
function Process-FilePackaging {
    Write-Host "`n开始文件打包过程..." -ForegroundColor Cyan

    try {
        $result = @{
            ZipPackage = $null
            DirectFiles = @{}
        }

        # 处理需要压缩的文件
        $compressedFiles = $config.buildOptions.embedMethods.compressed
        if ($compressedFiles -and $compressedFiles.Count -gt 0) {
            Write-Host "处理压缩文件..." -ForegroundColor Yellow
            $zipResult = Process-Files -FilePaths $compressedFiles -Method "zip"
            if ($zipResult) {
                $result.ZipPackage = $zipResult.Data
            }
        }

        # 处理直接嵌入的文件
        $directFiles = $config.buildOptions.embedMethods.direct
        if ($directFiles -and $directFiles.Count -gt 0) {
            Write-Host "处理直接嵌入文件..." -ForegroundColor Yellow
            $directResult = Process-Files -FilePaths $directFiles -Method "direct"
            if ($directResult) {
                $result.DirectFiles = $directResult.Data
            }
        }

        # 生成脚本内容
        $scriptContent = $originalContent

        # 更新直接嵌入的文件部分
        if ($result.DirectFiles.Count -gt 0) {
            $embeddedContent = "`$script:embeddedFiles = @{`n"
            foreach ($file in $result.DirectFiles.Keys) {
                $embeddedContent += "    '$file' = @'`n$($result.DirectFiles[$file])`n'@`n"
            }
            $embeddedContent += "}`n"

            # 替换嵌入文件标记
            $embedStart = "# BEGIN EMBEDDED FILES"
            $embedEnd = "# END EMBEDDED FILES"
            $startIndex = $scriptContent.IndexOf($embedStart)
            $endIndex = $scriptContent.IndexOf($embedEnd) + $embedEnd.Length
            if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
                $scriptContent = $scriptContent.Substring(0, $startIndex) +
                               "$embedStart`n$embeddedContent$embedEnd" +
                               $scriptContent.Substring($endIndex)
            }
        }

        # 更新压缩包部分
        if ($result.ZipPackage) {
            $packageContent = "`$script:packageBase64 = @'`n$($result.ZipPackage)`n'@`n"

            # 替换压缩包标记
            $zipStart = "# BEGIN EMBEDDED ZIP PACKAGE"
            $zipEnd = "# END EMBEDDED ZIP PACKAGE"
            $startIndex = $scriptContent.IndexOf("`$script:packageBase64 = @'")
            $endIndex = $scriptContent.IndexOf("'@", $startIndex)
            if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
                $beforeMarker = $scriptContent.Substring(0, $startIndex)
                $afterMarker = $scriptContent.Substring($endIndex + 2)
                $scriptContent = $beforeMarker + $packageContent + $afterMarker
            }
        }

        return $scriptContent
    }
    catch {
        Write-Host "打包过程出错: $_" -ForegroundColor Red
        return $null
    }
}

# 处理文件打包和函数生成
$newContent = Process-FilePackaging
if (-not $newContent) {
    Write-Host "警告: 文件处理失败，将继续生成无嵌入文件的脚本" -ForegroundColor Yellow
    $newContent = $originalContent
}

# 创建临时脚本文件
$tempScriptFile = Join-Path $scriptPath "temp_main_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"

# 写入临时脚本文件
try {
    # 使用UTF-8带BOM编码
    $utf8WithBomEncoding = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($tempScriptFile, $newContent, $utf8WithBomEncoding)

    # 验证文件是否成功创建
    if (Test-Path $tempScriptFile) {
        $fileInfo = Get-Item $tempScriptFile
        Write-Host "已创建包含嵌入文件的临时脚本: $tempScriptFile ($([Math]::Round($fileInfo.Length / 1MB, 2)) MB)" -ForegroundColor Green
    } else {
        Write-Host "错误: 临时脚本文件创建失败" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "错误: 无法写入临时脚本文件: $_" -ForegroundColor Red
    exit 1
}

# 准备ps2exe参数
$outputFile = Join-Path $rootPath $config.outputFile

# 构建基本命令
$ps2exeParams = @(
    "-inputFile `"$tempScriptFile`""
    "-outputFile `"$outputFile`""
)

# 添加版本信息参数
if ($config.versionInfo) {
    $versionInfo = $config.versionInfo

    # 基本版本号参数
    if ($versionInfo.fileVersion) {
        $ps2exeParams += "-version `"$($versionInfo.fileVersion)`""
    }

    # 其他元数据参数
    if ($versionInfo.company) {
        $ps2exeParams += "-company `"$($versionInfo.company)`""
    }
    if ($versionInfo.product) {
        $ps2exeParams += "-product `"$($versionInfo.product)`""
    }
    if ($versionInfo.description) {
        $ps2exeParams += "-description `"$($versionInfo.description)`""
    }
    if ($versionInfo.copyright) {
        $ps2exeParams += "-copyright `"$($versionInfo.copyright)`""
    }
    if ($versionInfo.trademark) {
        $ps2exeParams += "-trademark `"$($versionInfo.trademark)`""
    }
}

# 添加选项参数
if ($config.options) {
    $options = $config.options

    if ($options.requireAdmin -eq $true) {
        $ps2exeParams += "-requireAdmin"
    }

    if ($options.PSObject.Properties['noConsole'] -and $options.noConsole -eq $true) {
        $ps2exeParams += "-noConsole"
    }

    if ($options.supportOS -eq $true) {
        $ps2exeParams += "-supportOS"
    }

    if ($options.DPIAware -eq $true) {
        $ps2exeParams += "-DPIAware"
    }
}

# 构建完整命令
$ps2exeCommand = "ps2exe " + ($ps2exeParams -join " ")

# 显示命令
Write-Host "`n将执行以下命令:" -ForegroundColor Cyan
Write-Host $ps2exeCommand -ForegroundColor Yellow

# 询问用户是否继续
$continue = Read-Host "`n是否继续执行? (Y/N) [默认: Y]"
if ($continue -eq "N" -or $continue -eq "n") {
    Write-Host "操作已取消" -ForegroundColor Yellow

    # 清理临时文件
    if ($tempScriptFile -and (Test-Path $tempScriptFile)) {
        Remove-Item -Path $tempScriptFile -Force
        Write-Host "已删除临时脚本文件" -ForegroundColor Gray
    }

    exit 0
}

# 清除可能已存在的输出文件
if (Test-Path $outputFile) {
    Remove-Item -Path $outputFile -Force
}

# 执行PS2EXE命令
try {
    Invoke-Expression $ps2exeCommand | Out-Host

    # 检查结果
    if (Test-Path $outputFile) {
        $fileInfo = Get-Item $outputFile
        Write-Host "`n✅ 打包成功!" -ForegroundColor Green
        Write-Host "输出文件: $outputFile" -ForegroundColor Green
        Write-Host "文件大小: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green

        # 提示用户便携版的使用方式
        Write-Host "`n便携版使用说明:" -ForegroundColor Cyan
        Write-Host "1. 运行时临时文件将被解压到 %TEMP%\ZeroTier-portable-temp" -ForegroundColor Yellow
        Write-Host "2. 用户数据将存储在与EXE同级的 ZeroTierData 目录中" -ForegroundColor Yellow
        Write-Host "3. 退出时临时文件会自动清理" -ForegroundColor Yellow
    } else {
        Write-Host "`n❌ 打包失败: 未生成输出文件" -ForegroundColor Red
    }
}
catch {
    Write-Host "`n❌ 打包过程中发生错误: $_" -ForegroundColor Red
}

# 清理临时文件
if ($tempScriptFile -and (Test-Path $tempScriptFile)) {
    $deleteTempFile = Read-Host "`n是否删除临时脚本文件? (Y/N) [默认: Y]"
    if ($deleteTempFile -ne "N" -and $deleteTempFile -ne "n") {
        Remove-Item -Path $tempScriptFile -Force
        Write-Host "已删除临时脚本文件" -ForegroundColor Green
    } else {
        Write-Host "保留临时脚本文件: $tempScriptFile" -ForegroundColor Yellow
    }
}

Write-Host "`n打包过程完成" -ForegroundColor Cyan