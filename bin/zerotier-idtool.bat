@ECHO OFF
SETLOCAL
:: ZeroTier IDTool便携版包装器
:: 版本: 1.1.0
:: 日期: 2025-04-10

:: 检查是否需要显示帮助
IF "%1"=="help" (
    GOTO :SHOWHELP
)
IF "%1"=="-h" (
    GOTO :SHOWHELP
)

:: 检查是否使用inter参数（交互式身份管理）
IF "%1"=="inter" (
    ECHO 启动交互式身份管理工具...
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0..\ps\create-identity.ps1"
    EXIT /B %ERRORLEVEL%
)

:: 使用相对路径调用zerotier-one_x64.exe，-i不需要指定数据目录
"%~dp0zerotier-one_x64.exe" -i %*
GOTO :EOF

:SHOWHELP
ECHO ===================================================
ECHO      ZeroTier IDTool 便携版 - 帮助信息
ECHO      版本: 1.1.0
ECHO ===================================================
ECHO.
ECHO 描述:
ECHO     ZeroTier身份工具，用于管理ZeroTier身份和密钥。
ECHO.
ECHO 用法:
ECHO     zerotier-idtool [命令] [参数]
ECHO     zerotier-idtool help 或 -h    显示此帮助信息
ECHO     zerotier-idtool inter         启动交互式身份管理工具
ECHO.
ECHO 常用命令:
ECHO     generate [文件路径] [公钥文件路径]   - 生成新身份
ECHO     validate [身份文件]                 - 验证身份文件
ECHO     getpublic [身份文件]                - 从私钥获取公钥
ECHO     sign [身份文件] [文件]              - 使用身份签名文件
ECHO     verify [身份文件] [文件] [签名]      - 验证签名
ECHO     initmoon [第一个种子的身份公钥]      - 初始化moon
ECHO     genmoon [moon json文件]             - 生成moon
ECHO.
ECHO 注意:
ECHO     命令行参数直接传递给ZeroTier，完全兼容官方ZeroTier IDTool。
ECHO.
EXIT /B 0
