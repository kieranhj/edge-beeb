@echo off
rem make.bat - the build, for anyone who types `make`. A thin wrapper over
rem build.ps1, which is the build itself. `make run` and `make -Run` both
rem assemble and launch b-em; `make -Release` is the build for other people.
setlocal
set "ARGS=%*"
if /i "%~1"=="run" set "ARGS=-Run"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %ARGS%
exit /b %ERRORLEVEL%
