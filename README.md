# ZeroTier便携版

## 快速使用指南

### 准备工作

1. 准备一个U盘或可移动存储设备
2. 将整个`ZeroTier-portable`文件夹复制到U盘上

### 在新电脑上使用

1. 将U盘插入新电脑
2. **右键点击** `start.ps1`，选择**以管理员身份运行**
3. 在弹出的选择菜单中选择 **"1. 安装 ZeroTier"**
4. 首次使用时，系统将自动：
   - 提示创建网络身份（节点ID）
   - 询问是否需要配置自定义Planet服务器
   - 安装TAP虚拟网卡驱动
   - 添加命令行工具到系统路径
5. 安装完成后，使用以下命令加入您的网络：
   ```
   zerotier-cli join <网络ID>
   ```
6. 在ZeroTier控制面板中授权节点加入网络

就这么简单！现在您可以在任何Windows电脑上使用相同的ZeroTier身份进行连接。

### 常用命令

安装后，您可以在任何命令提示符或PowerShell中使用以下命令：

```
# 查看节点信息
zerotier-cli info

# 列出已加入的网络
zerotier-cli listnetworks

# 加入新网络
zerotier-cli join <网络ID>

# 离开网络
zerotier-cli leave <网络ID>

# 替换Planet文件（中国区加速等场景）
zerotier-cli replace

# 管理身份
zerotier-idtool inter
```

### 停止和卸载

- **停止服务**：关闭PowerShell窗口或在窗口中按Ctrl+C
- **卸载**：再次运行`start.ps1`，选择**"2. 卸载 ZeroTier"**选项

## 项目说明

ZeroTier便携版是一个可以存储在U盘上随身携带的ZeroTier客户端解决方案，无需安装，即插即用，并且可以在多台计算机间保持相同的网络身份标识。

### 主要特性

- **便携性**：可存储在U盘或移动硬盘上，跨设备使用
- **身份固定**：在不同设备上保持相同的ZeroTier节点ID
- **无需安装**：在新电脑上免安装运行
- **简单操作**：交互式界面，提供安装/卸载选项
- **命令行工具**：自动添加命令行工具到系统路径

### 文件结构

```
ZeroTier-portable/
├── bin/                    # ZeroTier可执行文件
│   ├── zerotier-one_x64.exe  # 主程序
│   ├── zerotier-cli.bat      # 命令行工具
│   ├── zerotier-idtool.bat   # 身份工具
│   └── tap-driver/          # TAP驱动文件
├── ps/                     # PowerShell辅助脚本
│   ├── create-identity.ps1  # 身份管理脚本
│   └── planet-replace.ps1   # Planet服务器配置脚本
├── data/                   # 持久化数据(自动创建)
│   ├── identity.secret      # 节点身份密钥
│   ├── identity.public      # 节点公钥
│   ├── planet              # 自定义根服务器文件(可选)
│   ├── networks.d/          # 网络配置
│   └── ...               # 其余自动配置文件
├── start.ps1               # 主启动脚本(安装/卸载)
└── README.md               # 使用说明
```

## 高级功能

### 身份管理

使用`zerotier-idtool inter`命令启动身份管理工具，您可以：

- **生成新身份**：创建新的ZeroTier节点ID（会改变您的网络身份）
- **导入身份**：从其他位置导入现有身份文件
- **备份身份**：将当前身份备份到安全位置
- **查看身份**：显示当前节点ID和身份信息

### Planet服务器配置

使用`zerotier-cli replace`命令启动Planet服务器配置工具：

- **从网络下载**：从URL下载自定义Planet文件
- **使用本地文件**：从本地导入Planet配置
- **查看当前配置**：分析当前Planet服务器信息
- **恢复默认配置**：删除自定义Planet，使用官方服务器

## 工作原理

ZeroTier便携版通过以下机制实现便携性和一致性：

1. **配置持久化**：所有配置存储在`data`目录而非系统目录
2. **身份保持**：通过保存`identity.secret`文件确保节点ID一致性
3. **临时运行**：使用命令行模式运行ZeroTier，而非系统服务
4. **动态安装**：TAP驱动按需安装，支持完整卸载
5. **全局访问**：在System32目录创建命令行工具链接，实现全局访问

与标准安装相比，便携版将所有文件集中存储在一个可移动目录中，通过PowerShell脚本动态创建运行环境，避免了在每台电脑上安装完整客户端。

## 故障排除

1. **命令行工具不可用**
   - 确认start.ps1已成功运行安装过程
   - 检查是否有权限问题阻止创建命令行链接

2. **网络连接问题**
   - 检查防火墙是否允许ZeroTier通信(UDP 9993端口)
   - 验证Planet服务器配置是否正确(如使用了自定义Planet)

3. **TAP驱动安装失败**
   - 查看安装过程中的错误信息
   - 尝试在设备管理器中手动安装tap-driver目录中的驱动

4. **节点ID变更**
   - 检查data目录是否完整保存
   - 使用身份管理工具恢复之前备份的身份

5. **卸载问题**
   - 如果卸载工具提示错误，可尝试手动删除System32目录中的命令行工具
   - 可在设备管理器中手动卸载TAP驱动