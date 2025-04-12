# 降低安全软件误报的修改指南

本文档提供了一系列修改建议，可以降低 ZeroTier 便携版被安全软件误报为恶意软件的风险。

## 可疑行为修改

### 1. 避免创建隐藏文件夹

在 `main.ps1` 中，我们将 ZeroTierData 文件夹设为隐藏属性。这可能触发安全软件的启发式检测。

**修改建议**：
- 移除设置隐藏属性的代码，使用普通文件夹
- 或者添加明确的用户通知，说明为什么需要创建隐藏文件夹

```powershell
# 原代码
$folder.Attributes = $folder.Attributes -bor [System.IO.FileAttributes]::Hidden

# 修改为
# 选项1: 不设置隐藏属性
Write-ZTLog "已创建数据存储目录: $dataPath" -Level Info -ForegroundColor Green

# 选项2: 添加明确通知
$folder.Attributes = $folder.Attributes -bor [System.IO.FileAttributes]::Hidden
Write-ZTLog "已创建数据存储目录并设为隐藏 (保护配置文件安全): $dataPath" -Level Info -ForegroundColor Green
```

### 2. 避免直接写入系统目录

在脚本中，我们向 `C:\Windows\System32` 添加或创建符号链接，这是高危行为。

**修改建议**：
- 使用环境变量 `%PATH%` 而非系统目录
- 在用户目录创建批处理文件，而非系统目录
- 在修改前明确询问用户许可

```powershell
# 修改思路示例
$userBinPath = Join-Path $env:USERPROFILE "ZeroTier\bin"
New-Item -ItemType Directory -Path $userBinPath -Force | Out-Null
Copy-Item $cliBat $userBinPath
# 然后添加 $userBinPath 到用户PATH环境变量
```

### 3. 避免使用特定的敏感命令组合

某些命令组合特别容易触发安全软件警报，例如:
- 创建隐藏文件夹 + 写入二进制文件
- 添加启动项 + 注册系统服务
- Base64解码 + 执行结果

**修改建议**：
- 拆分这些行为，在中间添加用户交互确认
- 添加详细日志，解释每个步骤的目的
- 提供跳过某些操作的选项

## 打包机制修改

### 1. 避免在一个步骤中嵌入所有二进制文件

当前方法是将所有二进制文件嵌入到一个大的Base64字符串中，这类似恶意软件的行为。

**修改建议**：
- 分离关键组件，使用单独的、更小的包
- 考虑使用更透明的资源嵌入机制，如 .NET 资源

### 2. 增强代码的可读性和透明度

**修改建议**：
- 添加详细注释解释代码目的
- 生成更多的日志信息
- 避免使用可能被误解的加密/解密/混淆技术

## PS2EXE 配置修改

### 1. 调整 PS2EXE 的编译选项

在 `ps2exe.config.json` 中修改一些编译选项可能有所帮助：

```json
"options": {
    "requireAdmin": true,     // 考虑改为 false，并在需要时再请求权限
    "noConsole": false,       // 保持 false 增加透明度
    "supportOS": true,
    "DPIAware": true,
    "virtualize": false       // 确保此项为 false
}
```

## 其他最佳实践

### 1. 提供SHA256哈希值

为您的发布版本提供官方SHA256哈希值，让用户可以验证文件完整性。

### 2. 开源代码

如果可能，将源代码开源，增强透明度和用户信任。

### 3. 添加详细的安装说明

在README中解释程序的所有行为，特别是那些需要系统权限的操作。

### 4. 向安全软件厂商提交误报申诉

如果您确信您的软件是安全的，可以向主要安全软件厂商提交误报申诉。通常需要提供:
- 软件的详细功能说明
- 为什么需要执行被标记为可疑的行为
- 源代码或可执行文件样本

## 结论

没有完全避免误报的万无一失方法，但通过实施上述建议，可以显著降低被错误标记为恶意软件的风险。最有效的方法是结合使用数字签名、透明的代码行为和良好的用户沟通。