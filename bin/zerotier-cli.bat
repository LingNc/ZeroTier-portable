@ECHO OFF
SETLOCAL
:: ZeroTier CLI Portable Wrapper
:: Version: 1.2.0
:: Date: 2025-04-10

:: Check if help is needed
IF "%1"=="help" (
    GOTO :SHOWHELP
)
IF "%1"=="-h" (
    GOTO :SHOWHELP
)

:: Check if using replace parameter
IF "%1"=="replace" (
    ECHO Starting Planet Replacement Tool...
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0..\ps\planet-replace.ps1"
    EXIT /B %ERRORLEVEL%
)

:: Set ZeroTier home directory to data folder in relative path
SET "ZT_HOME=%~dp0..\data"

:: Call zerotier-one_x64.exe using relative path with -q and -D parameters
"%~dp0zerotier-one_x64.exe" -q -D"%ZT_HOME%" %*
GOTO :EOF

:SHOWHELP
ECHO ===================================================
ECHO         ZeroTier CLI Portable - Help
ECHO         Version: 1.2.0
ECHO ===================================================
ECHO.
ECHO Description:
ECHO     ZeroTier command line interface tool for managing ZeroTier networks and connections.
ECHO.
ECHO Usage:
ECHO     zerotier-cli [command] [arguments]
ECHO     zerotier-cli help or -h    Show this help information
ECHO     zerotier-cli replace       Launch Planet replacement tool
ECHO.
ECHO Common Commands:
ECHO     info                    - Display node information
ECHO     listnetworks            - List all joined networks
ECHO     listpeers               - List all peers
ECHO     peers                   - List all peers (prettier format)
ECHO     join [network ID]       - Join a network
ECHO     leave [network ID]      - Leave a network
ECHO     set [network ID] [setting] - Set a network option
ECHO     listmoons               - List moons (federated root sets)
ECHO     orbit [world ID] [seed] - Join a moon
ECHO     deorbit [world ID]      - Leave a moon
ECHO.
ECHO Note:
ECHO     Command line arguments are passed directly to ZeroTier, fully compatible with official ZeroTier CLI.
ECHO.
EXIT /B 0
