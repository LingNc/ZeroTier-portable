@ECHO OFF
SETLOCAL
:: ZeroTier CLI便携版包装器
:: 版本: 1.1.0
:: 日期: 2025-04-10

:: 检查是否需要显示帮助
IF "%1"=="help" (
    GOTO :SHOWHELP
)
IF "%1"=="-h" (
    GOTO :SHOWHELP
)

:: 检查是否使用replace参数
IF "%1"=="replace" (
    ECHO 启动Planet替换工具...
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0..\ps\planet-replace.ps1"
    EXIT /B %ERRORLEVEL%
)

:: 设置ZeroTier主目录为相对路径下的data目录
SET "ZT_HOME=%~dp0..\data"

:: 使用相对路径调用zerotier-one_x64.exe，使用-q和-D参数
"%~dp0zerotier-one_x64.exe" -q -D"%ZT_HOME%" %*
GOTO :EOF

:SHOWHELP
ECHO ===================================================
ECHO         ZeroTier CLI 便携版 - 帮助信息
ECHO         版本: 1.1.0
ECHO ===================================================
ECHO.
ECHO 描述:
ECHO     ZeroTier命令行界面工具，用于管理ZeroTier网络和连接。
ECHO.
ECHO 用法:
ECHO     zerotier-cli [命令] [参数]
ECHO     zerotier-cli help 或 -h    显示此帮助信息
ECHO     zerotier-cli replace       启动Planet替换工具
ECHO.
ECHO 常用命令:
ECHO     info                    - 显示节点信息
ECHO     listnetworks            - 列出所有已加入的网络
ECHO     listpeers               - 列出所有对等节点
ECHO     peers                   - 美化格式显示对等节点
ECHO     join [网络ID]           - 加入网络
ECHO     leave [网络ID]          - 离开网络
ECHO     set [网络ID] [设置]     - 设置网络选项
ECHO     listmoons               - 列出所有moons(联邦根服务器集)
ECHO     orbit [world ID] [seed] - 加入moon
ECHO     deorbit [world ID]      - 离开moon
ECHO.
ECHO 注意:
ECHO     命令行参数直接传递给ZeroTier，完全兼容官方ZeroTier CLI。
ECHO.
EXIT /B 0
