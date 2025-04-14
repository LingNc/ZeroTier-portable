# ZeroTier-Portable / ZeroTier便携版

**依赖声明**
> 本项目使用 [ZeroTier](https://www.zerotier.com/) 的可执行文件`zerotier-one_x64`作为基础组件，
  其许可条款详见 [ZeroTier LICENSE](https://github.com/zerotier/ZeroTierOne/blob/master/LICENSE.txt)

### 简介
ZeroTier便携版是一个可以存储在U盘上随身携带的ZeroTier客户端解决方案，无需安装，即插即用，并且可以在多台Windows计算机间保持相同的网络身份标识。

### 协议
本项目代码采用 MIT 协议，但其中包含的 ZeroTier 组件仅限非商业使用。
商业用户需直接联系 ZeroTier 公司获取授权。

### 快速开始
1. 下载最新版本：
   - EXE版本：适合普通用户，直接运行
   - PS1版本：适合进阶用户，可修改源码

2. EXE模式使用方法：
   - 双击运行`ZeroTier-portable.exe`
   - 首次运行会请求管理员权限
   - 第一次需要按照界面提示完成初始化配置
   - 之后都直接遵循`ZeroTierData`的配置运行

3. PS1模式使用方法：
   - 解压PS1包到任意位置
   - 右键`start.ps1`选择"使用PowerShell运行"
   - 第一次请遵循界面提示完成初始化配置

### 主要功能
- 完全便携，安全的数据集中存储
- 双模式运行(EXE/PS1)
- 身份管理系统
- 自定义Planet服务器
- 全局命令行工具
- 完整的卸载清理

### 命令行工具
```shell
# 新增两功能
zerotier-cli help [or] -h    # 显示帮助信息
zerotier-cli replace         # 启动Planet配置工具
zerotier-idtool help [or] -h # 显示身份管理帮助信息
zerotier-idtool inter        # 启动身份管理工具

# 网络管理
zerotier-cli info            # 显示节点信息
zerotier-cli listnetworks    # 查看已加入的网络
zerotier-cli listpeers       # 查看节点列表
zerotier-cli peers           # 查看节点信息(更美观格式)
zerotier-cli join <网络ID>   # 加入网络
zerotier-cli leave <网络ID>  # 退出网络
zerotier-cli set <网络ID> <设置> # 设置网络选项
zerotier-cli listmoons       # 列出所有moons(联邦根服务器)
zerotier-cli orbit <world ID> <seed> # 加入moon
zerotier-cli deorbit <world ID> # 离开moon

# 身份工具
zerotier-idtool generate <文件路径> <公钥路径> # 生成新身份
zerotier-idtool validate <身份文件>  # 验证身份文件
zerotier-idtool getpublic <身份文件> # 从私钥获取公钥
zerotier-idtool sign <身份文件> <文件> # 使用身份签名文件
zerotier-idtool verify <身份文件> <文件> <签名> # 验证签名
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
│   ├── temp/                # 临时构建文件目录(自动创建)
│   └── ps2exe.config.yaml   # 编译配置文件
├── data/                    # 数据目录(PS1模式,自动创建)
│   ├── identity.secret      # 身份密钥
│   ├── identity.public      # 公钥文件
│   ├── planet              # 根服务器配置
│   └── networks.d/          # 网络配置
├── ZeroTierData/           # 数据目录(EXE模式,自动创建)
│   ├── identity.secret      # 身份密钥
│   ├── identity.public      # 公钥文件
│   ├── planet              # 根服务器配置
│   └── networks.d/          # 网络配置
├── releases/               # 发布目录
│   ├──  ZeroTier-portable.exe  # EXE版本
│   └── ZeroTier-portable.zip  # PS1版本
├── LICENSE.md              # 许可证文件
├── README.md               # 项目说明文件
└── main.ps1                # 主程序入口文件
```

#### 运行模式
1. **EXE模式**
   - 资源打包在EXE内
   - 运行时解压到临时目录
   - 使用ZeroTierData保存配置(该配置会在运行时被链接到`%TEMP%`的指定文件夹中，供程序访问使用)
      所以在EXE模式下，使用命令行工具查看身份(`zerotier-idtool inter`)的时候，查看身份会显示在`%TEMP%`文件夹中

2. **PS1模式**
   - 包含完整源文件结构
   - 通过`start.ps1`启动
   - 便于修改和定制

#### 构建过程
1. 使用`build.ps1`进行构建：
   - 编译EXE版本(嵌入式资源)
   - 打包PS1版本(完整文件结构)
   - 临时文件存储在`build/temp`目录

2. 构建配置(`ps2exe.config.json`):
   - 分离EXE与PS1模式配置
   - 自定义版本信息和图标
   - 灵活的文件打包规则
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

### 开发环境
- Windows 10/11
- PowerShell 5.1+
- PS2EXE模块
- powershell-yaml模块
- Visual Studio Code

### 致谢
- ZeroTier官方
- PowerShell社区

---
Made with ❤️ by LingNc