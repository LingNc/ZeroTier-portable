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

# 检查配置文件中指定的目录是否存在
if ($config.PSObject.Properties['package'] -or $config.PSObject.Properties['includes']) {
    $packageItems = if ($config.PSObject.Properties['package']) { $config.package } else { $config.includes }
    $allDirsExist = $true

    foreach ($pattern in $packageItems) {
        $pattern = $pattern.Replace("\\", "\")
        $dirPath = Split-Path -Parent $pattern

        if (-not [string]::IsNullOrEmpty($dirPath)) {
            $fullDirPath = Join-Path $rootPath $dirPath
            if (-not (Test-Path $fullDirPath -PathType Container)) {
                Write-Host "警告: 配置中指定的目录不存在: $fullDirPath" -ForegroundColor Yellow
                $allDirsExist = $false
            }
        }
    }

    if ($allDirsExist) {
        Write-Host "✅ 检查完成，所有必要文件和目录已找到" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 部分目录可能不存在，请检查配置文件" -ForegroundColor Yellow
        $continue = Read-Host "是否继续? (Y/N) [默认: N]"
        if ($continue -ne "Y" -and $continue -ne "y") {
            exit 1
        }
    }
} else {
    Write-Host "✅ 检查完成，所有必要文件已找到" -ForegroundColor Green
}

# 如果需要嵌入文件，修改主脚本
$tempScriptFile = $null
$needEmbedCode = $false

# 处理嵌入配置
$embedMethodsConfig = $false
$compressedFiles = @()
$directEmbedFiles = @()
$ignoredFiles = @()
$useCompression = $false

# 检查是否存在嵌入方法配置
if ($config.PSObject.Properties['buildOptions'] -and
    $config.buildOptions.PSObject.Properties['embedMethods']) {
    $embedMethodsConfig = $true

    # 获取各类文件配置
    if ($config.buildOptions.embedMethods.PSObject.Properties['compressed']) {
        $compressedFiles = $config.buildOptions.embedMethods.compressed
    }
    if ($config.buildOptions.embedMethods.PSObject.Properties['direct']) {
        $directEmbedFiles = $config.buildOptions.embedMethods.direct
    }
    if ($config.buildOptions.embedMethods.PSObject.Properties['ignore']) {
        $ignoredFiles = $config.buildOptions.embedMethods.ignore
    }

    # 检查是否启用压缩功能
    if ($config.buildOptions.PSObject.Properties['compressPackage']) {
        $useCompression = $config.buildOptions.compressPackage
        $compressStatusText = if ($useCompression) { "启用" } else { "禁用" }
        Write-Host "使用配置文件中的压缩选项: $compressStatusText" -ForegroundColor Yellow
    }

    Write-Host "`n检测到自定义嵌入配置:" -ForegroundColor Cyan
    Write-Host "- 压缩嵌入文件: $($compressedFiles.Count) 个模式" -ForegroundColor Yellow
    Write-Host "- 直接嵌入文件: $($directEmbedFiles.Count) 个模式" -ForegroundColor Yellow
    Write-Host "- 忽略的文件: $($ignoredFiles.Count) 个模式" -ForegroundColor Yellow
}

if ($config.PSObject.Properties['package'] -or $config.PSObject.Properties['includes']) {
    $packageItems = if ($config.PSObject.Properties['package']) { $config.package } else { $config.includes }
    if ($packageItems -and $packageItems.Count -gt 0) {
        $needEmbedCode = $true

        if ($embedMethodsConfig) {
            Write-Host "`n将使用自定义的嵌入方式处理文件" -ForegroundColor Cyan
        } else {
            Write-Host "`n注意: ps2exe不支持直接打包文件，将采用文件二进制嵌入方式" -ForegroundColor Yellow
        }
    }
}

# 创建临时脚本文件
$tempScriptFile = Join-Path $scriptPath "temp_main_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"

# 读取原始脚本内容
$originalContent = Get-Content $mainScript -Raw

# 检查是否已经包含了依赖文件处理代码
if ($originalContent -match "# BEGIN EMBEDDED FILES") {
    Write-Host "主脚本已包含嵌入文件代码，将创建新的临时脚本" -ForegroundColor Yellow
}

# 构建嵌入代码头部
$embeddedCode = @"
# BEGIN EMBEDDED FILES
# 此代码段包含嵌入到脚本中的二进制文件
# 运行时将自动解压到临时目录

`$embeddedFiles = @{}
`$scriptRoot = `$PSScriptRoot
if (-not `$scriptRoot) { `$scriptRoot = Split-Path -Parent `$MyInvocation.MyCommand.Path }
`$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "ZeroTier-Portable-$(Get-Random)"

"@

# 为每个压缩目录执行打包
$packagers = @{}

if ($useCompression) {
    foreach ($pattern in $compressedFiles) {
        $pattern = $pattern.Replace("\\", "\")
        $dirPath = Split-Path -Parent $pattern
        $filePattern = Split-Path -Leaf $pattern

        # 提取目录名称
        if ([string]::IsNullOrEmpty($dirPath)) {
            # 如果是根目录下的通配符
            if ($filePattern -eq "*" -or $filePattern -eq "*.*") {
                $dirToPackage = "root"
            } else {
                $dirToPackage = $filePattern.Replace("*", "").Replace(".", "")
            }
        } else {
            # 使用目录路径的第一段作为标识
            $dirToPackage = $dirPath.Split('\')[0]
        }

        # 如果尚未处理过此目录
        if (-not $packagers.ContainsKey($dirToPackage)) {
            $packagers[$dirToPackage] = $pattern

            # 检查打包脚本是否存在
            $packageScript = Join-Path $scriptPath "package-bin.ps1"
            if (-not (Test-Path $packageScript)) {
                Write-Host "错误: 找不到目录打包脚本: $packageScript" -ForegroundColor Red
                Write-Host "将使用直接嵌入方式替代" -ForegroundColor Yellow
                continue
            }

            # 执行目录打包
            Write-Host "`n正在打包 $dirToPackage 目录..." -ForegroundColor Cyan

            # 构建输出名称
            $outputName = $dirToPackage

            # 执行打包命令
            & $packageScript -SourceDirectory $dirToPackage -OutputName $outputName -Force

            # 检查打包结果
            $outputPath = Join-Path -Path $scriptPath -ChildPath "$outputName-package"
            $extractCodeFile = Join-Path -Path $outputPath -ChildPath "extract-code.ps1"

            if (Test-Path $extractCodeFile) {
                $extractCode = Get-Content $extractCodeFile -Raw
                $embeddedCode += @"
# 嵌入 $dirToPackage 目录解压代码
$extractCode

"@
                Write-Host "✅ 已嵌入 $dirToPackage 目录的解压代码" -ForegroundColor Green
            } else {
                Write-Host "⚠️ $dirToPackage 目录打包失败，未找到解压代码文件" -ForegroundColor Yellow
                # 从处理过的目录中移除
                $packagers.Remove($dirToPackage)
            }
        }
    }
}

# 添加常规文件解压函数
$embeddedCode += @"
function Extract-EmbeddedFiles {
    param(
        [string]`$DestinationPath = `$tempDir
    )

    if (-not (Test-Path `$DestinationPath -PathType Container)) {
        New-Item -Path `$DestinationPath -ItemType Directory -Force | Out-Null
        Write-Host "创建临时目录: `$DestinationPath" -ForegroundColor Gray
    }

    Write-Host "正在解压嵌入文件到临时目录..." -ForegroundColor Yellow

    foreach (`$fileName in `$embeddedFiles.Keys) {
        `$filePath = Join-Path `$DestinationPath `$fileName
        `$fileDir = Split-Path -Parent `$filePath

        # 确保目录存在
        if (-not (Test-Path `$fileDir -PathType Container)) {
            New-Item -Path `$fileDir -ItemType Directory -Force | Out-Null
        }

        # 解码并写入文件
        try {
            `$bytes = [System.Convert]::FromBase64String(`$embeddedFiles[`$fileName])
            [System.IO.File]::WriteAllBytes(`$filePath, `$bytes)
            Write-Host "  已解压: `$fileName" -ForegroundColor Gray
        } catch {
            Write-Host "  解压失败: `$fileName - `$_" -ForegroundColor Red
        }
    }

    Write-Host "所有文件已解压到 `$DestinationPath" -ForegroundColor Green
    return `$DestinationPath
}

# 在程序启动时准备环境
function Initialize-Environment {
    # 清理和创建临时目录
    if (Test-Path `$tempDir -PathType Container) {
        try {
            Remove-Item -Path `$tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "清理旧的临时目录: `$tempDir" -ForegroundColor Gray
        } catch {
            Write-Host "清理旧目录失败: `$_" -ForegroundColor Yellow
        }
    }

    New-Item -Path `$tempDir -ItemType Directory -Force | Out-Null
    Write-Host "创建临时目录: `$tempDir" -ForegroundColor Gray

    # 解压常规嵌入文件
    `$extractedPath = Extract-EmbeddedFiles

"@

# 添加每个压缩目录的解压代码
foreach ($dirName in $packagers.Keys) {
    $functionName = "Extract-${dirName}Package"
    $embeddedCode += @"
    # 解压 $dirName 目录
    if (Get-Command -Name $functionName -ErrorAction SilentlyContinue) {
        `$$($dirName)Path = Join-Path `$tempDir "$dirName"
        New-Item -Path `$$($dirName)Path -ItemType Directory -Force | Out-Null
        $functionName -DestinationPath `$$($dirName)Path
    }

"@
}

$embeddedCode += @"
    # 设置环境变量
    `$env:ZEROTIER_PORTABLE_ROOT = `$tempDir
    return `$tempDir
}

# 在程序结束时清理临时文件
`$cleanupScript = {
    if (Test-Path `$tempDir -PathType Container) {
        try {
            Remove-Item -Path `$tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Verbose "已清理临时目录: `$tempDir"
        } catch {
            Write-Verbose "清理失败: `$_"
        }
    }
}
Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action `$cleanupScript | Out-Null

# 初始化环境
`$portableRoot = Initialize-Environment

# 嵌入的文件内容
"@

# 收集并添加文件
$filesAdded = 0
$compressedFilesAdded = 0
$directEmbedFilesAdded = 0
$totalFiles = 0
$totalSize = 0
$processedPaths = @()

# 如果需要嵌入常规文件
if ($needEmbedCode) {
    # 处理每个路径模式
    foreach ($pattern in $packageItems) {
        # 处理路径
        $pattern = $pattern.Replace("\\", "\")
        $dirPath = Split-Path -Parent $pattern
        $filePattern = Split-Path -Leaf $pattern

        # 根据嵌入方式配置决定如何处理
        $embeddingMethod = "direct" # 默认直接嵌入
        $skipPattern = $false

        if ($embedMethodsConfig) {
            # 检查是否应该跳过这个模式
            foreach ($ignorePattern in $ignoredFiles) {
                if ($pattern -like $ignorePattern -or $pattern -eq $ignorePattern) {
                    $skipPattern = $true
                    Write-Host "  跳过模式: $pattern (在忽略列表中)" -ForegroundColor Gray
                    break
                }
            }

            if ($skipPattern) { continue }

            # 检查是否应该压缩这个模式
            foreach ($compressPattern in $compressedFiles) {
                if ($pattern -like $compressPattern -or $pattern -eq $compressPattern) {
                    $embeddingMethod = "compressed"
                    break
                }
            }

            # 已经检查了忽略和压缩，如果不是压缩，则检查是否是直接嵌入
            if ($embeddingMethod -ne "compressed") {
                foreach ($directPattern in $directEmbedFiles) {
                    if ($pattern -like $directPattern -or $pattern -eq $directPattern) {
                        $embeddingMethod = "direct"
                        break
                    }
                }
            }
        }

        # 如果是压缩嵌入且已经处理过该目录，则跳过
        if ($embeddingMethod -eq "compressed") {
            $dirToCheck = if ([string]::IsNullOrEmpty($dirPath)) {
                $filePattern.Replace("*", "").Replace(".", "")
            } else {
                $dirPath.Split('\')[0]
            }

            if ($packagers.ContainsKey($dirToCheck)) {
                Write-Host "  跳过模式: $pattern (由压缩包机制处理)" -ForegroundColor Gray
                continue
            }
        }

        # ...existing code...

        if (($embeddingMethod -eq "direct") -or (-not $embedMethodsConfig)) {
            # ...原来处理直接嵌入文件的代码...
            if ([string]::IsNullOrEmpty($dirPath)) {
                $fullPath = Join-Path $rootPath $filePattern
            } else {
                $fullPath = Join-Path $rootPath $dirPath
                if (-not (Test-Path $fullPath -PathType Container)) {
                    Write-Host "  警告: 目录不存在: $fullPath" -ForegroundColor Yellow
                    continue
                }
                $fullPath = Join-Path $fullPath $filePattern
            }

            # 检查是否有通配符
            $hasWildcard = $filePattern -match '\*'

            # 解析通配符获取文件
            try {
                Write-Host "  正在搜索: $fullPath (直接嵌入)" -ForegroundColor Gray

                # 使用适当的参数调用Get-ChildItem
                if ($hasWildcard) {
                    # 有通配符时使用-Recurse，但只对*.*或只有*的情况
                    $isFullRecursive = $filePattern -eq "*" -or $filePattern -eq "*.*"
                    $files = Get-ChildItem -Path $fullPath -File -Recurse:$isFullRecursive -ErrorAction Stop
                } else {
                    # 没有通配符时直接查找文件
                    if (Test-Path -Path $fullPath -PathType Leaf) {
                        $files = @(Get-Item -Path $fullPath)
                    } else {
                        $files = @()
                    }
                }

                $totalFiles += $files.Count

                if ($files.Count -eq 0) {
                    Write-Host "  警告: 没有找到匹配的文件: $fullPath" -ForegroundColor Yellow
                    continue
                }

                foreach ($file in $files) {
                    # 检查文件是否已处理（避免重复）
                    if ($processedPaths -contains $file.FullName) {
                        Write-Host "  跳过重复文件: $($file.FullName)" -ForegroundColor Gray
                        continue
                    }

                    $relativePath = $file.FullName.Substring($rootPath.Length + 1)
                    $fileSize = $file.Length
                    $totalSize += $fileSize

                    Write-Host "  处理文件: $relativePath ($([Math]::Round($fileSize / 1KB, 2)) KB) [直接嵌入]" -ForegroundColor Gray

                    # 读取二进制内容并转换为Base64
                    try {
                        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
                        $base64 = [System.Convert]::ToBase64String($bytes)

                        # 添加到嵌入代码
                        $embeddedCode += "`n`$embeddedFiles['$relativePath'] = @'`n$base64`n'@`n"
                        $filesAdded++
                        $directEmbedFilesAdded++

                        # 记录已处理文件
                        $processedPaths += $file.FullName
                    } catch {
                        Write-Host "  错误: 无法读取文件 $($file.FullName): $_" -ForegroundColor Red
                    }
                }
            } catch {
                Write-Host "  警告: 处理 $pattern 时出错 - $_" -ForegroundColor Yellow
            }
        }
    }
}

# 关闭嵌入代码
$embeddedCode += "`n# END EMBEDDED FILES`n`n"

# 显示嵌入文件统计
Write-Host "已嵌入 $filesAdded 个常规文件 (总计找到 $totalFiles 个匹配)" -ForegroundColor Green
Write-Host "- 直接嵌入: $directEmbedFilesAdded 个文件" -ForegroundColor Green

if ($packagers.Count -gt 0) {
    Write-Host "- 压缩嵌入: $($packagers.Count) 个目录 ($($packagers.Keys -join ', '))" -ForegroundColor Green
}

Write-Host "嵌入数据大小约 $([Math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Green

# 将嵌入代码和原始内容合并
$newContent = $embeddedCode + $originalContent

# 写入临时脚本文件 (使用UTF-8带BOM编码)
try {
    # 使用UTF-8带BOM编码，设置第一个参数为true表示使用BOM
    $utf8WithBomEncoding = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($tempScriptFile, $newContent, $utf8WithBomEncoding)

    # 验证文件是否成功创建
    if (Test-Path $tempScriptFile) {
        $fileInfo = Get-Item $tempScriptFile
        Write-Host "已创建包含嵌入文件的临时脚本: $tempScriptFile ($([Math]::Round($fileInfo.Length / 1MB, 2)) MB)" -ForegroundColor Green
        Write-Host "使用UTF-8带BOM编码，以确保正确处理中文字符" -ForegroundColor Cyan
    } else {
        Write-Host "错误: 临时脚本文件创建失败" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "错误: 无法写入临时脚本文件: $_" -ForegroundColor Red
    exit 1
}

# 确定要使用的输入文件
$inputFile = $tempScriptFile
Write-Host "使用脚本文件: $inputFile" -ForegroundColor Cyan

# 准备ps2exe参数
$outputFile = Join-Path $rootPath $config.outputFile

# 构建基本命令
$ps2exeParams = @(
    "-inputFile `"$inputFile`""
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

    # 正确处理noConsole参数
    if ($options.PSObject.Properties['noConsole']) {
        if ($options.noConsole -eq $true) {
            $ps2exeParams += "-noConsole"
        }
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

# 执行命令
Write-Host "`n正在打包..." -ForegroundColor Cyan

# 清除可能已存在的输出文件
if (Test-Path $outputFile) {
    Remove-Item -Path $outputFile -Force
}

$success = $false
try {
    # 执行PS2EXE命令
    Invoke-Expression $ps2exeCommand | Out-Host

    # 明确检查结果
    if (Test-Path $outputFile) {
        $fileInfo = Get-Item $outputFile
        if ($fileInfo.Length -gt 1MB) {  # 确保文件不是空的或太小
            $success = $true
            Write-Host "`n✅ 打包成功!" -ForegroundColor Green
            Write-Host "输出文件: $outputFile" -ForegroundColor Green
            Write-Host "文件大小: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Green

            # 确认依赖文件处理方式
            if ($useCompression) {
                Write-Host "`n依赖文件处理:" -ForegroundColor Green
                Write-Host "脚本已嵌入所有必要文件，包括压缩目录" -ForegroundColor Green
                Write-Host "运行时文件会被自动解压到临时目录: %TEMP%\ZeroTier-Portable-随机数" -ForegroundColor Green
                Write-Host "程序退出时会自动清理临时文件" -ForegroundColor Green
            } elseif ($needEmbedCode) {
                Write-Host "`n依赖文件处理:" -ForegroundColor Green
                Write-Host "脚本已嵌入常规依赖文件" -ForegroundColor Green
                Write-Host "运行时文件会被自动解压到临时目录: %TEMP%\ZeroTier-Portable-随机数" -ForegroundColor Green
                Write-Host "程序退出时会自动清理临时文件" -ForegroundColor Green
            } else {
                Write-Host "`n注意：EXE中未包含依赖文件" -ForegroundColor Yellow
                Write-Host "您需要确保以下文件/目录与生成的EXE位于同一目录下:" -ForegroundColor Yellow
                Write-Host "  - bin/ 目录 (包含主程序和命令行工具)" -ForegroundColor Yellow
                Write-Host "  - ps/ 目录 (包含辅助脚本)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n❌ 打包可能失败: 生成的文件异常小 ($([Math]::Round($fileInfo.Length / 1KB, 2)) KB)" -ForegroundColor Red
        }
    } else {
        Write-Host "`n❌ 打包失败: 未生成输出文件" -ForegroundColor Red
    }
}
catch {
    Write-Host "`n❌ 打包过程中发生错误: $_" -ForegroundColor Red
}

# 如果使用了临时文件，询问是否删除
if ($tempScriptFile -and (Test-Path $tempScriptFile)) {
    if ($success) {
        $deleteTempFile = Read-Host "`n是否删除临时脚本文件? (Y/N) [默认: Y]"
        if ($deleteTempFile -ne "N" -and $deleteTempFile -ne "n") {
            try {
                Remove-Item -Path $tempScriptFile -Force -ErrorAction Stop
                Write-Host "已删除临时脚本文件" -ForegroundColor Green
            } catch {
                Write-Host "无法删除临时脚本文件: $_" -ForegroundColor Yellow
                Write-Host "文件路径: $tempScriptFile" -ForegroundColor Yellow
            }
        } else {
            Write-Host "保留临时脚本文件: $tempScriptFile" -ForegroundColor Yellow
        }
    } else {
        Write-Host "保留临时脚本文件用于调试: $tempScriptFile" -ForegroundColor Yellow
    }
}

Write-Host "`n打包过程完成" -ForegroundColor Cyan