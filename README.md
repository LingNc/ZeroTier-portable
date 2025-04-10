# ZeroTier便携版

## 简介

ZeroTier便携版是一个可在多台计算机间便携使用的ZeroTier客户端解决方案。无需安装，即插即用，并且可以保持相同的网络身份标识。

## 特性

- **便携性**: 可存储在U盘或移动硬盘上，跨设备使用
- **身份固定**: 在不同设备上保持相同的ZeroTier节点ID
- **数据持久化**: 所有配置和网络设置跟随设备移动
- **无需安装**: 在新电脑上免安装运行
- **适用于Windows**: 支持Windows平台（需管理员权限）

## 文件结构

```
ZeroTier-portable/
├── bin/                     # 可执行文件路径
│   ├── zerotier-one_x64.exe  # 主程序
│   ├── zerotier-cli.bat      # 命令行工具
│   ├── zerotier-idtool.bat   # 命令行工具
│   └── tap-driver/          # TAP驱动
├── data/                    # 持久化数据路径
│   ├── identity.secret       # 节点身份密钥
│   ├── authtoken.secret      # API认证令牌
│   ├── planet               # 自定义根服务器文件
│   └── networks.d/          # 网络配置
├── create-identity.ps1      # 身份管理脚本
├── planet-replace.ps1       # Planet替换脚本
├── start.ps1                # 启动脚本
├── zt-cli.ps1               # 命令行工具包装器
└── README.md                # 使用说明
```

## 使用方法

### 首次设置

1. 从官方下载ZeroTier客户端（Windows版本）
2. 解压缩官方安装包，提取以下文件:
   - ZeroTier One安装目录下的`zerotier-one_x64.exe`
   - ZeroTier One安装目录下的`zerotier-cli.bat`和`zerotier-idtool.bat`
   - ZeroTier One安装目录下的`tap-driver`文件夹
3. 创建一个名为`ZeroTier-portable`的文件夹
4. 在该文件夹内创建`bin`和`data`子文件夹
5. 将提取的文件复制到对应位置
6. 下载本仓库中的PowerShell脚本到根目录

### 启动ZeroTier

1. 右键点击`start.ps1`，选择"以管理员身份运行"（首次运行需要安装TAP驱动）
2. 脚本会自动:
   - 检查并安装TAP驱动（如果需要）
   - 生成身份（如果是首次运行）
   - 启动ZeroTier服务
3. 启动后，您可以使用`zt-cli.ps1`来管理网络

### 管理身份

使用`create-identity.ps1`脚本（右键以管理员身份运行）:

1. **生成新身份**: 创建新的ZeroTier节点ID（谨慎使用，会改变您的节点ID）
2. **导入身份文件**: 从其他位置导入现有身份
3. **备份当前身份**: 将身份文件备份到指定位置
4. **查看当前身份**: 显示当前使用的身份信息

### 管理Planet服务器

如果需要自定义Planet服务器（用于中国区加速等场景），使用`planet-replace.ps1`脚本:

1. **从网络下载**: 从URL下载Planet文件并应用
2. **使用本地文件**: 从本地文件导入Planet配置
3. **查看当前配置**: 显示当前Planet文件信息
4. **恢复默认配置**: 删除自定义Planet文件，恢复使用官方服务器

### 常用命令

启动ZeroTier后，使用以下命令加入/管理网络:

```powershell
# 加入网络
.\zt-cli.ps1 join <网络ID>

# 离开网络
.\zt-cli.ps1 leave <网络ID>

# 列出已加入的网络
.\zt-cli.ps1 listnetworks

# 查看节点信息
.\zt-cli.ps1 info

# 查看对等节点
.\zt-cli.ps1 peers
```

## 迁移到新电脑

只需将整个`ZeroTier-portable`文件夹复制到新电脑上，然后运行`start.ps1`即可。由于身份文件保存在`data`目录中，您的节点ID将保持不变。

## 注意事项

- **需要管理员权限**: 脚本需要以管理员权限运行才能正常工作
- **防火墙设置**: 首次在新设备上运行时，需允许ZeroTier通过Windows防火墙
- **数据安全**: `data/identity.secret`文件包含您的私钥，请妥善保管
- **备份建议**: 定期使用`create-identity.ps1`脚本备份您的身份文件
- **网络连接**: 使用自定义Planet文件可能会影响与官方网络的兼容性

## 故障排除

1. **无法连接网络**
   - 检查防火墙是否允许ZeroTier通信
   - 确认Planet文件配置正确（如使用了自定义Planet）

2. **TAP驱动安装失败**
   - 确认是否以管理员权限运行脚本
   - 检查Windows设备管理器中是否有错误设备

3. **节点ID改变**
   - 检查`data/identity.secret`文件是否存在
   - 使用`create-identity.ps1`脚本恢复备份

## 升级ZeroTier版本

要升级ZeroTier版本，只需更新`bin`目录中的可执行文件:

1. 下载新版本的ZeroTier安装程序
2. 提取新版本的文件
3. 替换`bin`目录中的对应文件
4. 重新运行`start.ps1`