@ECHO OFF
SETLOCAL
:: ZeroTier IDTool Portable Wrapper
:: Version: 1.2.0
:: Date: 2025-04-10

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
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0..\ps\create-identity.ps1"
    EXIT /B %ERRORLEVEL%
)

:: Call zerotier-one_x64.exe using relative path, no need to specify data directory with -i
"%~dp0zerotier-one_x64.exe" -i %*
GOTO :EOF

:SHOWHELP
ECHO ===================================================
ECHO      ZeroTier IDTool Portable - Help
ECHO      Version: 1.2.0
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
