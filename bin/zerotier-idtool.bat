@ECHO OFF
SETLOCAL

SET "ZT_HOME=%~dp0..\data"

"%~dp0zerotier-one_x64.exe" -i %*
