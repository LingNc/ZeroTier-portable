@ECHO OFF
SETLOCAL EnableDelayedExpansion

:: ZeroTier IDTool Portable Wrapper
:: Version: 1.4.0
:: Date: 2025-04-14

:: ZeroTier portable的位置固定在临时目录中
SET "ZT_INSTALL_PATH=%TEMP%\ZeroTier-portable-temp"

:: 检查文件是否存在
IF NOT EXIST "%ZT_INSTALL_PATH%\bin\zerotier-one_x64.exe" (
    ECHO 错误: 无法找到ZeroTier程序文件。
    ECHO 请确保ZeroTier便携版正在运行。
    EXIT /B 1
)

:: Check if help is needed
IF "%1"=="help" (
    GOTO :SHOWHELP
)
IF "%1"=="-h" (
    GOTO :SHOWHELP
)

:: Check if using inter parameter (interactive identity management)
IF "%1"=="inter" (
    ECHO Starting Interactive Identity Management Tool...
    powershell.exe -ExecutionPolicy Bypass -File "%ZT_INSTALL_PATH%\ps\create-identity.ps1"
    EXIT /B %ERRORLEVEL%
)

:: Call zerotier-one_x64.exe using absolute path
"%ZT_INSTALL_PATH%\bin\zerotier-one_x64.exe" -i %*
GOTO :EOF

:SHOWHELP
ECHO ===================================================
ECHO      ZeroTier IDTool Portable - Help
ECHO      Version: 1.4.0
ECHO ===================================================
ECHO.
ECHO Description:
ECHO     ZeroTier identity tool for managing ZeroTier identities and keys.
ECHO.
ECHO Usage:
ECHO     zerotier-idtool [command] [arguments]
ECHO     zerotier-idtool help or -h    Show this help information
ECHO     zerotier-idtool inter         Launch interactive identity management tool
ECHO.
ECHO Common Commands:
ECHO     generate [file_path] [public_key_path]   - Generate new identity
ECHO     validate [identity_file]                 - Validate identity file
ECHO     getpublic [identity_file]                - Get public key from private key
ECHO     sign [identity_file] [file]              - Sign file with identity
ECHO     verify [identity_file] [file] [signature] - Verify signature
ECHO     initmoon [first_seed_identity_public]    - Initialize moon
ECHO     genmoon [moon_json_file]                 - Generate moon
ECHO.
ECHO Note:
ECHO     Command line arguments are passed directly to ZeroTier, fully compatible with official ZeroTier IDTool.
ECHO.
EXIT /B 0
