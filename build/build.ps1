# ZeroTier便携版打包脚本
# 通过配置文件自动打包EXE
# 作者: LingNc

# 设置编码为UTF8，确保正确处理中文
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

#region 初始化变量

# 获取脚本所在目录
$scriptPath = $PSScriptRoot
if (!$scriptPath) { $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path }

# 获取根目录
$rootPath = Split-Path -Parent $scriptPath

# 配置文件路径
$configFile = Join-Path $scriptPath "ps2exe.config.json"

# 创建临时文件目录
$tempRoot = Join-Path $scriptPath "temp"
if (-not (Test-Path $tempRoot)) {
    New-Item -Path $tempRoot -ItemType Directory -Force | Out-Null
}

#endregion

#region 辅助函数

# 检查并安装ps2exe模块
function Initialize-PS2EXEModule {
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
            return $false
        }
    } else {
        Write-Host "已检测到ps2exe模块" -ForegroundColor Green
        # 显示版本信息
        $ps2exeVersion = (Get-Module -ListAvailable -Name ps2exe | Sort-Object Version -Descending | Select-Object -First 1).Version
        Write-Host "ps2exe模块版本: $ps2exeVersion" -ForegroundColor Green
    }
    return $true
}

# 处理文件打包（压缩或直接Base64编码）
function Process-Files {
    param(
        [string[]]$FilePaths,
        [string]$Method = "zip",
        [string]$TempDir = (Join-Path $tempRoot "zt_packaging_$(Get-Date -Format 'yyyyMMdd_HHmmss')")
    )

    Write-Host "正在处理文件: $($FilePaths -join ', ')" -ForegroundColor Yellow
    Write-Host "处理方式: $Method" -ForegroundColor Yellow
    Write-Host "临时目录: $TempDir" -ForegroundColor Gray

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
                TempDir = $TempDir
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
                TempDir = $TempDir
            }
        }
    }
    catch {
        Write-Host "处理文件时出错: $_" -ForegroundColor Red
        return $null
    }
}

# 准备PS2EXE参数
function Get-PS2EXEParameters {
    param(
        [string]$InputFile,
        [string]$OutputFile,
        [PSCustomObject]$Config
    )

    # 构建基本命令
    $params = @(
        "-inputFile `"$InputFile`""
        "-outputFile `"$OutputFile`""
    )

    # 添加图标参数
    if ($Config.iconFile) {
        $iconPath = Join-Path $rootPath $Config.iconFile
        if (Test-Path $iconPath) {
            $params += "-iconFile `"$iconPath`""
            Write-Host "使用自定义图标: $iconPath" -ForegroundColor Green
        } else {
            Write-Host "警告: 指定的图标文件不存在: $iconPath" -ForegroundColor Yellow
        }
    }

    # 添加版本信息参数
    if ($Config.versionInfo) {
        $versionInfo = $Config.versionInfo

        # 基本版本号参数
        if ($versionInfo.fileVersion) {
            $params += "-version `"$($versionInfo.fileVersion)`""
        }

        # 其他元数据参数
        if ($versionInfo.company) {
            $params += "-company `"$($versionInfo.company)`""
        }
        if ($versionInfo.product) {
            $params += "-product `"$($versionInfo.product)`""
        }
        if ($versionInfo.description) {
            $params += "-description `"$($versionInfo.description)`""
        }
        if ($versionInfo.copyright) {
            $params += "-copyright `"$($versionInfo.copyright)`""
        }
        if ($versionInfo.trademark) {
            $params += "-trademark `"$($versionInfo.trademark)`""
        }
    }

    # 添加选项参数
    if ($Config.options) {
        $options = $Config.options

        if ($options.requireAdmin -eq $true) {
            $params += "-requireAdmin"
        }

        if ($options.PSObject.Properties['noConsole'] -and $options.noConsole -eq $true) {
            $params += "-noConsole"
        }

        if ($options.supportOS -eq $true) {
            $params += "-supportOS"
        }

        if ($options.DPIAware -eq $true) {
            $params += "-DPIAware"
        }
    }

    return $params
}

# 清理临时目录
function Remove-BuildTempDir {
    param(
        [string]$TempDir
    )

    if ($TempDir -and (Test-Path $TempDir)) {
        $deleteTempDir = Read-Host "`n是否删除临时目录? (Y/N) [默认: Y]"
        if ($deleteTempDir -ne "N" -and $deleteTempDir -ne "n") {
            Remove-Item -Path $TempDir -Recurse -Force
            Write-Host "已删除临时目录: $TempDir" -ForegroundColor Green
        } else {
            Write-Host "保留临时目录: $TempDir" -ForegroundColor Yellow
        }
    }
}

#endregion

#region 打包功能实现

# 处理文件嵌入和创建修改后的脚本
function New-EmbeddedScript {
    param(
        [string]$SourceScript,
        [PSCustomObject]$ExeConfig
    )

    Write-Host "`n开始文件打包过程..." -ForegroundColor Cyan

    try {
        # 读取原始脚本内容
        $originalContent = Get-Content $SourceScript -Raw

        $result = @{
            ZipPackage = $null
            DirectFiles = @{}
            TempDirs = @()
        }

        # 处理需要压缩的文件
        $compressedFiles = $ExeConfig.buildOptions.embedMethods.compressed
        if ($compressedFiles -and $compressedFiles.Count -gt 0) {
            Write-Host "处理压缩文件..." -ForegroundColor Yellow
            $zipResult = Process-Files -FilePaths $compressedFiles -Method "zip"
            if ($zipResult) {
                $result.ZipPackage = $zipResult.Data
                $result.TempDirs += $zipResult.TempDir
            }
        }

        # 处理直接嵌入的文件
        $directFiles = $ExeConfig.buildOptions.embedMethods.direct
        if ($directFiles -and $directFiles.Count -gt 0) {
            Write-Host "处理直接嵌入文件..." -ForegroundColor Yellow
            $directResult = Process-Files -FilePaths $directFiles -Method "direct"
            if ($directResult) {
                $result.DirectFiles = $directResult.Data
                $result.TempDirs += $directResult.TempDir
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
            $startIndex = $scriptContent.IndexOf($zipStart)
            $endIndex = $scriptContent.IndexOf($zipEnd) + $zipEnd.Length
            if ($startIndex -ge 0 -and $endIndex -gt $startIndex) {
                $scriptContent = $scriptContent.Substring(0, $startIndex) +
                               "$zipStart`n$packageContent$zipEnd" +
                               $scriptContent.Substring($endIndex)
            } else {
                # 尝试直接替换 packageBase64 变量
                $startIndex = $scriptContent.IndexOf("`$script:packageBase64 = @'")
                if ($startIndex -ge 0) {
                    $endIndex = $scriptContent.IndexOf("'@", $startIndex)
                    if ($endIndex -gt $startIndex) {
                        $beforeMarker = $scriptContent.Substring(0, $startIndex)
                        $afterMarker = $scriptContent.Substring($endIndex + 2)
                        $scriptContent = $beforeMarker + $packageContent + $afterMarker
                    }
                }
            }
        }

        return @{
            Content = $scriptContent
            TempDirs = $result.TempDirs
        }
    }
    catch {
        Write-Host "打包过程出错: $_" -ForegroundColor Red
        return $null
    }
}

# 打包EXE版本
function New-EXEPackage {
    param(
        [string]$TempScriptFile,
        [PSCustomObject]$ExeConfig
    )

    Write-Host "`n开始打包EXE版本..." -ForegroundColor Cyan

    # 获取输出文件路径
    $outputFile = Join-Path $rootPath $ExeConfig.outputFile

    # 获取PS2EXE参数
    $ps2exeParams = Get-PS2EXEParameters -InputFile $TempScriptFile -OutputFile $outputFile -Config $ExeConfig

    # 构建完整命令
    $ps2exeCommand = "ps2exe " + ($ps2exeParams -join " ")

    # 显示命令
    Write-Host "`n将执行以下命令:" -ForegroundColor Cyan
    Write-Host $ps2exeCommand -ForegroundColor Yellow

    # 询问用户是否继续
    $continue = Read-Host "`n是否继续执行? (Y/N) [默认: Y]"
    if ($continue -eq "N" -or $continue -eq "n") {
        Write-Host "操作已取消" -ForegroundColor Yellow
        return $false
    }

    # 清除可能已存在的输出文件
    if (Test-Path $outputFile) {
        Remove-Item -Path $outputFile -Force
    }

    # 确保输出目录存在
    $outputDir = Split-Path -Parent $outputFile
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # 执行PS2EXE命令
    try {
        Invoke-Expression $ps2exeCommand | Out-Host

        # 检查结果
        if (Test-Path $outputFile) {
            $fileInfo = Get-Item $outputFile
            Write-Host "`n✅ EXE打包成功!" -ForegroundColor Green
            Write-Host "输出文件: $outputFile" -ForegroundColor Green
            Write-Host "文件大小: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green
            return $true
        } else {
            Write-Host "`n❌ 打包失败: 未生成输出文件" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "`n❌ 打包过程中发生错误: $_" -ForegroundColor Red
        return $false
    }
}

# 打包ZIP版本
function New-ZIPPackage {
    param (
        [PSCustomObject]$ZipConfig
    )

    Write-Host "`n开始打包ZIP版本..." -ForegroundColor Cyan

    # 创建临时目录
    $tempDir = Join-Path $tempRoot "zt_zip_packaging_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Write-Host "创建临时打包目录: $tempDir" -ForegroundColor Gray

    # 获取输出路径
    $outputFile = Join-Path $rootPath $ZipConfig.outputFile
    $outputDir = Split-Path -Parent $outputFile

    # 创建输出目录
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    # 创建打包目录
    $packageDir = Join-Path $tempDir $ZipConfig.structure.rootFolder
    Write-Host "创建ZIP根目录结构: $packageDir" -ForegroundColor Gray

    try {
        New-Item -ItemType Directory -Path $packageDir -Force | Out-Null

        # 复制文件
        foreach ($pattern in $ZipConfig.files) {
            # 构造源路径（相对于根目录）
            $sourcePath = Join-Path $rootPath $pattern

            # 输出处理信息
            Write-Host "处理文件模式: $pattern" -ForegroundColor Gray

            # 处理文件复制逻辑
            if ($pattern -like "*/**") {
                # 这是目录通配符模式（例如 bin/**）
                $dirPattern = $pattern -replace "/\*\*$", ""
                $dirPath = Join-Path $rootPath $dirPattern

                if (Test-Path $dirPath -PathType Container) {
                    $targetDir = Join-Path $packageDir $dirPattern

                    # 确保目标目录存在
                    if (-not (Test-Path $targetDir)) {
                        New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                    }

                    # 复制所有内容，保持目录结构
                    $sourceItems = Get-ChildItem -Path $dirPath -Recurse
                    foreach ($item in $sourceItems) {
                        $relativePath = $item.FullName.Substring($dirPath.Length)
                        $targetPath = Join-Path $targetDir $relativePath

                        if ($item.PSIsContainer) {
                            if (-not (Test-Path $targetPath)) {
                                New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
                            }
                        } else {
                            $targetItemDir = Split-Path -Parent $targetPath
                            if (-not (Test-Path $targetItemDir)) {
                                New-Item -Path $targetItemDir -ItemType Directory -Force | Out-Null
                            }
                            Copy-Item -Path $item.FullName -Destination $targetPath -Force
                        }
                    }

                    # 输出复制成功信息
                    Write-Host "已复制目录结构: $dirPath -> $targetDir" -ForegroundColor Green
                }
            }
            else {
                # 单个文件或文件通配符（如 ps/*.ps1）
                $files = Get-ChildItem -Path $sourcePath -File -ErrorAction SilentlyContinue

                if ($files.Count -gt 0) {
                    foreach ($file in $files) {
                        # 获取相对路径部分（例如 "ps/script.ps1" 中的 "ps"）
                        $relativeDir = Split-Path -Parent ($pattern -replace "\*.*", "")
                        $targetDir = Join-Path $packageDir $relativeDir

                        # 确保目标目录存在
                        if (-not (Test-Path $targetDir)) {
                            New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                        }

                        $targetPath = Join-Path $targetDir (Split-Path -Leaf $file)
                        Copy-Item -Path $file.FullName -Destination $targetPath -Force
                        Write-Host "已复制文件: $($file.Name) -> $targetPath" -ForegroundColor Green
                    }
                } else {
                    # 尝试作为单个文件处理
                    if (Test-Path $sourcePath -PathType Leaf) {
                        $targetPath = Join-Path $packageDir (Split-Path -Leaf $sourcePath)
                        Copy-Item -Path $sourcePath -Destination $targetPath -Force
                        Write-Host "已复制文件: $(Split-Path -Leaf $sourcePath) -> $targetPath" -ForegroundColor Green
                    } else {
                        Write-Host "警告: 未找到匹配的文件: $pattern" -ForegroundColor Yellow
                    }
                }
            }
        }

        # 复制并重命名主脚本
        $mainScriptSource = Join-Path $scriptPath "main.ps1"
        $mainScriptTarget = Join-Path $packageDir $ZipConfig.structure.mainScript

        # 确保目标目录存在
        $mainScriptTargetDir = Split-Path -Parent $mainScriptTarget
        if (-not (Test-Path $mainScriptTargetDir) -and $mainScriptTargetDir -ne "") {
            New-Item -Path $mainScriptTargetDir -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path $mainScriptSource -Destination $mainScriptTarget -Force
        Write-Host "已复制主脚本: $mainScriptSource -> $mainScriptTarget" -ForegroundColor Green

        # 创建ZIP文件
        if (Test-Path $outputFile) {
            Remove-Item $outputFile -Force
        }

        Write-Host "正在创建ZIP文件: $outputFile" -ForegroundColor Yellow
        # 使用绝对路径确保正确处理
        Compress-Archive -Path $packageDir -DestinationPath $outputFile -Force

        # 显示结果
        if (Test-Path $outputFile) {
            $fileInfo = Get-Item $outputFile
            Write-Host "`n✅ ZIP版本打包成功!" -ForegroundColor Green
            Write-Host "输出文件: $outputFile" -ForegroundColor Green
            Write-Host "文件大小: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green
            return @{ Success = $true; TempDir = $tempDir }
        }
        else {
            Write-Host "`n❌ ZIP版本打包失败: 未生成输出文件" -ForegroundColor Red
            return @{ Success = $false; TempDir = $tempDir }
        }
    }
    catch {
        Write-Host "`n❌ ZIP版本打包出错: $_" -ForegroundColor Red
        return @{ Success = $false; TempDir = $tempDir }
    }
}

#endregion

#region 主程序

# 处理PS1版本
function New-PS1Package {
    param(
        [PSCustomObject]$ExeConfig
    )

    Write-Host "`n开始准备PS1版本..." -ForegroundColor Cyan

    # 获取主脚本路径
    $mainScript = Join-Path $rootPath $ExeConfig.inputFile

    if (-not (Test-Path $mainScript -PathType Leaf)) {
        Write-Host "错误: 找不到主脚本文件: $mainScript" -ForegroundColor Red
        return $false
    }

    # 创建嵌入文件的脚本
    $scriptResult = New-EmbeddedScript -SourceScript $mainScript -ExeConfig $ExeConfig
    if (-not $scriptResult) {
        Write-Host "警告: 文件处理失败，将继续生成无嵌入文件的脚本" -ForegroundColor Yellow
        $newContent = Get-Content $mainScript -Raw
        $scriptResult = @{
            Content = $newContent
            TempDirs = @()
        }
    }

    # 创建临时脚本文件
    $tempScriptFile = Join-Path $tempRoot "temp_main_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"

    # 写入临时脚本文件
    try {
        # 使用UTF-8带BOM编码
        $utf8WithBomEncoding = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($tempScriptFile, $scriptResult.Content, $utf8WithBomEncoding)

        # 验证文件是否成功创建
        if (Test-Path $tempScriptFile) {
            $fileInfo = Get-Item $tempScriptFile
            Write-Host "已创建包含嵌入文件的临时脚本: $tempScriptFile ($([Math]::Round($fileInfo.Length / 1MB, 2)) MB)" -ForegroundColor Green
            return @{
                TempScriptFile = $tempScriptFile
                TempDirs = $scriptResult.TempDirs
            }
        } else {
            Write-Host "错误: 临时脚本文件创建失败" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "错误: 无法写入临时脚本文件: $_" -ForegroundColor Red
        return $false
    }
}

# 清理临时文件
function Remove-TempFile {
    param(
        [string]$TempFile
    )

    if ($TempFile -and (Test-Path $TempFile)) {
        $deleteTempFile = Read-Host "`n是否删除临时脚本文件? (Y/N) [默认: Y]"
        if ($deleteTempFile -ne "N" -and $deleteTempFile -ne "n") {
            Remove-Item -Path $TempFile -Force
            Write-Host "已删除临时脚本文件" -ForegroundColor Green
        } else {
            Write-Host "保留临时脚本文件: $TempFile" -ForegroundColor Yellow
        }
    }
}

# 主执行逻辑
function Start-Packaging {
    # 显示欢迎信息
    Write-Host @"
===================================================
         ZeroTier便携版打包工具
         日期: $(Get-Date -Format "yyyy-MM-dd")
===================================================
"@ -ForegroundColor Cyan

    # 检查配置文件是否存在
    if (-not (Test-Path $configFile)) {
        Write-Host "错误: 找不到配置文件 $configFile" -ForegroundColor Red
        return $false
    }

    # 读取配置文件
    try {
        $config = Get-Content $configFile -Raw | ConvertFrom-Json
        Write-Host "已成功读取配置文件" -ForegroundColor Green

        if ($config.exe.versionInfo) {
            Write-Host "版本: $($config.exe.versionInfo.fileVersion)" -ForegroundColor Cyan
        }
    } catch {
        Write-Host "错误: 无法解析配置文件: $_" -ForegroundColor Red
        return $false
    }

    # 初始化PS2EXE模块
    if (-not (Initialize-PS2EXEModule)) {
        return $false
    }

    $success = $true
    $tempFiles = @()
    $tempDirs = @()

    # 根据配置执行打包
    foreach ($target in $config.buildTargets) {
        switch ($target) {
            "exe" {
                # 生成PS1临时文件
                $ps1Result = New-PS1Package -ExeConfig $config.exe
                if (-not $ps1Result) {
                    $success = $false
                    continue
                }

                $tempFiles += $ps1Result.TempScriptFile
                $tempDirs += $ps1Result.TempDirs

                # 打包EXE版本
                $success = $success -and (New-EXEPackage -TempScriptFile $ps1Result.TempScriptFile -ExeConfig $config.exe)

                if ($success) {
                    # 提示用户便携版的使用方式
                    Write-Host "`n便携版使用说明:" -ForegroundColor Cyan
                    Write-Host "1. 运行时临时文件将被解压到 %TEMP%\ZeroTier-portable-temp" -ForegroundColor Yellow
                    Write-Host "2. 用户数据将存储在与EXE同级的 ZeroTierData 目录中" -ForegroundColor Yellow
                    Write-Host "3. 退出时临时文件会自动清理" -ForegroundColor Yellow
                }
            }
            "zip" {
                # 打包ZIP版本
                $zipResult = New-ZIPPackage -ZipConfig $config.zip
                $success = $success -and $zipResult.Success
                if ($zipResult.TempDir) {
                    $tempDirs += $zipResult.TempDir
                }
            }
            default {
                Write-Host "警告: 未知的打包目标: $target" -ForegroundColor Yellow
            }
        }
    }

    # 清理临时文件和目录
    foreach ($file in $tempFiles) {
        Remove-TempFile -TempFile $file
    }

    foreach ($dir in $tempDirs | Select-Object -Unique) {
        Remove-BuildTempDir -TempDir $dir
    }

    # 询问是否清理总临时目录
    if ((Get-ChildItem -Path $tempRoot -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
        $cleanTempRoot = Read-Host "`n临时目录已为空，是否删除临时根目录? (Y/N) [默认: Y]"
        if ($cleanTempRoot -ne "N" -and $cleanTempRoot -ne "n") {
            Remove-Item -Path $tempRoot -Force
            Write-Host "已删除临时根目录: $tempRoot" -ForegroundColor Green
        }
    }

    # 显示最终结果
    if ($success) {
        Write-Host "`n✅ 所有打包任务已完成" -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ 部分打包任务失败" -ForegroundColor Yellow
    }

    return $success
}

# 执行主程序
$result = Start-Packaging
if (-not $result) {
    exit 1
}

#endregion