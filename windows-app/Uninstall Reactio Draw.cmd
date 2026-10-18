@echo off
set "EXE=%~dp0ReactioDraw.exe"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" if exist "%~dp0ReactioDraw-ARM.exe" set "EXE=%~dp0ReactioDraw-ARM.exe"
"%EXE%" /unregister
