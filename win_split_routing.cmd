@echo off
goto :START
DATA#subnets
10.0.0.0/8       # PRIVATE-ADDRESS-ABLK-RFC1918-IANA-RESERVED
172.16.0.0/12    # PRIVATE-ADDRESS-BBLK-RFC1918-IANA-RESERVED
192.168.0.0/16   # PRIVATE-ADDRESS-CBLK-RFC1918-IANA-RESERVED
156.54.0.0/16    # AS3269 Netsiel
163.162.0.0/16   # AS5609 CSELT
194.243.135.0/24 # AS3269 INTERBUSINESS
DATA#end

:START

:: The index of the interface connected to the global internet (see: netsh interface ipv4 show interface)
:: Most likely the WiFi interface
set INTERNET_IF_IDX=13
:: The index of the interface connected to the LAN
set LAN_IF_IDX=8

setlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

if "%1"=="on" (
  set ACTION=on
) else if "%1"=="off" (
  set ACTION=off
) else if "%1"=="show" (
  call :SHOWIF
  call :SHOWPR
  pause
  exit /b
) else (
  echo Usage: win_split_routing on^|off^|show
  pause
  exit /b
)

call :CHECKADMIN

set THISFILE=%~f0

call :GETIFPARM

if "%INTERNET_IF_NAME%"=="" (
  echo Cannot find interface %INTERNET_IF_IDX%
  call :SHOWIF
  exit /b
)

if %ACTION%==off (
  call :TURNOFF
  pause
  exit /b
)

if %LAN_IF_METRIC% LEQ 5 (
  echo Cannot find a suitable LAN_IF_METRIC for interface %LAN_IF_IDX%
  call :SHOWIF
  exit /b
)

call :GETDEFGW
if not defined DEFGATEWAY (
  echo Cannot find default gateway of interface %LAN_IF_IDX% "%LAN_IF_NAME%"
  exit /b
)

echo Current metric of interface %LAN_IF_IDX% "%LAN_IF_NAME%" is %LAN_IF_METRIC%

:: Set TARGET_INTERNET_METRIC to 5 less than LAN_IF_METRIC (instead of automatic) as to prioritize INTERNET_IF_IDX
set /A TARGET_INTERNET_METRIC=LAN_IF_METRIC-5
echo.
echo Setting metric=%TARGET_INTERNET_METRIC% for interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%"
netsh interface ipv4 set interface interface=%INTERNET_IF_IDX% metric=%TARGET_INTERNET_METRIC%
call :SHOWIF

echo Current default gateway of interface %LAN_IF_IDX% "%LAN_IF_NAME%" is %DEFGATEWAY%
echo.

call :SETPR %DEFGATEWAY%

call :SHOWPR

pause
goto :EOF

:: ===========================================================================
:: Subroutines

:CHECKADMIN
:: Check administrative privileges
fsutil dirty query %systemdrive% > nul
if %ERRORLEVEL% LSS 1 goto :EOF
echo  This script must run with "elevated privileges", therefore:
echo    right-click and choose "Run as administrator",
echo    or run it from an elevated console,
echo    or run it from gsudo.
echo.
pause
exit /b

:GETIFPARM
:: Find metric and name of interfaces
set LAN_IF_METRIC=0
for /f "tokens=1,2,3,4*" %%a in ('netsh interface ipv4 show interface') do (
  if %%a EQU %LAN_IF_IDX% (
    set LAN_IF_METRIC=%%b
    set LAN_IF_NAME=%%e
  )
  if %%a EQU %INTERNET_IF_IDX% (
    set INTERNET_IF_NAME=%%e
  )
)
goto :EOF

:TURNOFF
echo Re-enabling automatic metric for interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%"
netsh interface ipv4 set interface interface=%INTERNET_IF_IDX% metric=0
call :SHOWIF
echo Removing routes:
set status=0
for /f "tokens=1,2 delims=#" %%a in (%THISFILE%) do (
  if %%a==DATA (
    if !status!==1 (
      goto :ROUTESREMOVED
    ) else if %%b==subnets (
      set status=1
    ) else if %%b==end (
      goto :ROUTESREMOVED
    )
  ) else (
    if !status!==1 (
      echo %%a%%b
      route delete %%a 2> nul
    )
  )
)
:ROUTESREMOVED
call :SHOWPR
goto :EOF

:GETDEFGW
:: Gets the default gateway of the interface LAN_IF_IDX
set DEFGATEWAY=
for /f "tokens=1,2,3,4,5*" %%a in ('netsh interface ipv4 show route') do (
  if %%d%%e==0.0.0.0/0%LAN_IF_IDX% (
    set DEFGATEWAY=%%f
    goto :EOF
  )
)
goto :EOF

:SETPR
:: Get subnets from this file and set permanent local routes 
set DEFGW=%1
echo Setting permanent routes via %DEFGW%:
set status=0
for /f "tokens=1,2 delims=#" %%a in (%THISFILE%) do (
  if %%a==DATA (
    if !status!==1 (
      goto :EOF
    ) else if %%b==subnets (
      set status=1
    ) else if %%b==end (
      goto :EOF
    )
  ) else (
    if !status!==1 (
      echo %%a%%b
      route -p add %%a %DEFGW% 2> nul
    )
  )
)
goto :EOF

:SHOWPR
:: Show permanent routes
set count=0
for /f "tokens=1 delims=" %%a in ('route -4 print') do (
  set a=%%a
  set a=!a:~0,1!
  if "!a!"=="=" set /A count+=1
  if !count! EQU 4 echo %%a
)
echo.
goto :EOF

:SHOWIF
:: Show interfaces
netsh interface ipv4 show interface
set count=0
for /f "tokens=1 delims=" %%a in ('route -4 print') do (
  set a=%%a
  set a=!a:~0,1!
  if "!a!"=="=" set /A count+=1
  if !count! EQU 1 echo %%a
)
echo.
goto :EOF
