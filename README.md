# ZeroTier-Portable / ZeroTier便携版

### 简介
ZeroTier便携版是一个可以存储在U盘上随身携带的ZeroTier客户端解决方案，无需安装，即插即用，并且可以在多台Windows计算机间保持相同的网络身份标识。

### 协议
MIT开源协议
版权所有 © 2025 绫袅LingNc

### 快速开始
1. 下载最新版本：
   - EXE版本：适合普通用户，直接运行
   - PS1版本：适合进阶用户，可修改源码

2. EXE模式使用方法：
   - 双击运行`ZeroTier-portable.exe`
   - 首次运行会请求管理员权限
   - 按照界面提示完成配置

3. PS1模式使用方法：
   - 解压ZIP包到任意位置
   - 右键`start.ps1`选择"使用PowerShell运行"
   - 遵循界面提示完成配置

### 主要功能
- 完全便携，数据集中存储
- 双模式运行(EXE/PS1)
- 身份管理系统
- 自定义Planet服务器
- 全局命令行工具
- 完整的卸载清理

### 命令行工具
```
zerotier-cli join <网络ID>    # 加入网络
zerotier-cli listnetworks     # 查看已加入的网络
zerotier-cli info            # 查看节点信息
zerotier-cli leave <网络ID>   # 退出网络
zerotier-cli set <网络ID> allowManaged=1   # 允许托管配置
zerotier-cli replace         # 启动Planet配置工具
zerotier-idtool inter       # 启动身份管理工具
```

### 计划功能
- [ ] 系统托盘图标支持
- [ ] GUI配置界面
- [ ] 多语言支持
- [ ] 自动更新功能
- [ ] 网络连接状态监控
- [ ] 配置文件导入导出

### 高级使用教程

#### 身份管理
使用`zerotier-idtool inter`命令进入交互式身份管理：
1. 生成新身份
2. 导入现有身份
3. 备份当前身份
4. 查看身份信息

#### Planet服务器配置
使用`zerotier-cli replace`命令配置自定义根服务器：
1. 在线下载配置
2. 本地文件导入
3. 恢复官方配置

### 故障排除指南

#### 1. 启动问题
- 确保以管理员权限运行
- 检查防病毒软件是否拦截
- 确认TAP驱动安装正确
- 查看日志文件排查问题

#### 2. 网络连接问题
- 检查防火墙设置
- 验证网络ID是否正确
- 确认Planet服务器配置
- 检查系统时间同步

#### 3. 卸载清理
- 使用内置卸载功能
- 清理残留文件和注册表
- 检查TAP驱动移除情况

### 技术实现原理

#### 文件结构
```
ZeroTier-portable/
├── bin/                    # 核心程序目录
│   ├── zerotier-one_x64.exe  # ZeroTier主程序
│   ├── zerotier-cli.bat      # 命令行工具
│   ├── zerotier-idtool.bat   # 身份管理工具
│   └── tap-driver/           # TAP网卡驱动
├── ps/                     # PowerShell脚本
│   ├── create-identity.ps1   # 身份管理脚本
│   └── planet-replace.ps1    # Planet配置脚本
├── build/                  # 构建相关文件
│   ├── main.ps1             # 主程序源码
│   ├── build.ps1            # 构建脚本
│   └── ps2exe.config.json   # 编译配置文件
├── data/                   # 数据目录(自动创建)
│   ├── identity.secret      # 身份密钥
│   ├── identity.public      # 公钥文件
│   ├── planet              # 根服务器配置
│   └── networks.d/          # 网络配置
└── releases/               # 发布目录
    └── ...                # 发布的文件
```

#### 运行模式
1. **EXE模式**
   - 资源打包在EXE内
   - 运行时解压到临时目录
   - 使用ZeroTierData保存配置

2. **PS1模式**
   - 直接使用源文件
   - 就地运行程序
   - 使用data目录保存配置

#### 构建过程
1. 使用build.ps1进行构建：
   - 编译EXE版本
   - 打包PS1版本
   - 生成发布文件

2. 构建配置(ps2exe.config.json):
   - 版本信息设置
   - 资源打包规则
   - 运行权限配置

#### 数据持久化
- 身份文件保存机制
- 网络配置存储
- 日志记录系统
- Planet服务器配置

### 问题反馈
如遇问题请提交Issue，包含以下信息：
1. 运行模式(EXE/PS1)
2. 系统版本
3. 错误信息
4. 日志文件

### 贡献代码
欢迎提交Pull Request，请确保：
1. 代码风格统一
2. 添加注释说明
3. 更新文档
4. 测试通过

### 开发环境
- Windows 10/11
- PowerShell 5.1+
- PS2EXE工具
- Visual Studio Code

### 致谢
- ZeroTier官方
- PowerShell社区
- 所有贡献者

---
Made with ❤️ by LingNc