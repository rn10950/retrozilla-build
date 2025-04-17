@echo off
SETLOCAL ENABLEEXTENSIONS
CALL %~dp0\RZ_BUILD_SETTINGS.BAT

REM Check for 32-bit cmd
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
ECHO.
ECHO retrozilla-build can't run in 64-bit cmd.exe
ECHO Please run %WINDIR%\SysWOW64\cmd.exe
ECHO.
PAUSE
GOTO EOF
)

REM Initialize build system
SET MOZ_MSVCVERSION=6
SET MOZBUILDDIR=%~dp0
SET MOZILLABUILD=%MOZBUILDDIR%

echo "Mozilla tools directory: %MOZBUILDDIR%"

REM Get MSVC paths
call "%MOZBUILDDIR%guess-msvc.bat"

if "%VC6DIR%"=="" (
    ECHO "Microsoft Visual C++ version 6 was not found. Exiting."
    pause
    EXIT /B 1
)

REM For MSVC6, we use the "old" non-static moztools
set MOZ_TOOLS=%MOZBUILDDIR%moztools-180compat

rem append moztools to PATH
SET PATH=%PATH%;%MOZ_TOOLS%\bin

rem Prepend MSVC paths
call "%VC6DIR%\Bin\vcvars32.bat"

cd "%USERPROFILE%"


REM determine terminal type
IF DEFINED RZ_TERMINAL ( GOTO RUN_SHELL )

REM No Shell set, prompt user
ECHO.
ECHO Select Terminal Emulator:
ECHO =========================
ECHO.
ECHO 1 ) win32 Console
ECHO 2 ) MinTTY
ECHO 3 ) rxvt
ECHO.
SET /P RZ_TERMINAL=[1, 2, 3]: 

:RUN_SHELL

IF %RZ_TERMINAL%==1 GOTO T1
IF %RZ_TERMINAL%==2 GOTO T2
IF %RZ_TERMINAL%==3 GOTO T3

ECHO Invalid terminal setting, quitting.
GOTO EOF

:T1
REM CMD
%MOZILLABUILD%\msys\bin\bash --login -i
GOTO EOF

:T2
REM MinTTY
start "MSYS Shell - MSVC6 Environment" "%MOZILLABUILD%\msys\bin\mintty" -e /bin/bash --login -i
GOTO EOF

:T3
REM rxvt
start "MSYS Shell - MSVC6 Environment" "%MOZILLABUILD%\msys\bin\rxvt" -backspacekey  -sl 2500 -fg %FGCOLOR% -bg %BGCOLOR% -sr -tn msys -geometry 80x25 -e /bin/bash --login -i
GOTO EOF

:EOF