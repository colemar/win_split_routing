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
set INTERNET_IF_IDX=11
:: The index of the interface connected to the LAN
set LAN_IF_IDX=7

setlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: Capture 0x1B (escape) into variable ESC
for /f "delims=" %%E in ('forfiles /p "%~dp0." /m "%~nx0" /c "cmd /c echo(0x1B"') do (
  set "ESC=%%E["
)

if "%1"=="on" (
  set ACTION=on
) else if "%1"=="off" (
  set ACTION=off
) else if "%1"=="show" (
  call :SHOWIF
  call :SHOWDEFGW
  call :SHOWROUTES
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
  exit /b 1
)

if %ACTION%==off (
  call :TURNOFF
  pause
  exit /b
)

if %LAN_IF_METRIC%=="" (
  echo Cannot find metric for interface %LAN_IF_IDX%
  call :SHOWIF
  exit /b 1
)

call :GETDEFGW
if not defined LAN_DEFGATEWAY (
  echo Cannot find default gateway of interface %LAN_IF_IDX% "%LAN_IF_NAME%"
  exit /b 1
)
if not defined INTERNET_DEFGATEWAY (
  echo Cannot find default gateway of interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%"
  exit /b 1
)

echo Current metric of interface %LAN_IF_IDX% "%LAN_IF_NAME%" is %LAN_IF_METRIC%

echo.
echo Setting metric=1 for interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%"
netsh interface ipv4 set interface interface=%INTERNET_IF_IDX% metric=1
call :SHOWIF

call :GETRM
if not defined LAN_R_METRIC (
  echo Cannot find default route metric of interface %LAN_IF_IDX% "%LAN_IF_NAME%"
  exit /b 1
)
if not defined INTERNET_R_METRIC (
  echo Cannot find default route metric of interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%"
  exit /b 1
)

echo Current default gateway of interface %LAN_IF_IDX% "%LAN_IF_NAME%" is %LAN_DEFGATEWAY%
echo Current default gateway of interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%" is %INTERNET_DEFGATEWAY%
echo.

call :SETPR %LAN_DEFGATEWAY%

call :SHOWROUTES

if %INTERNET_R_METRIC% GEQ %LAN_R_METRIC% (
  echo The default route metric for interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%" ^(%INTERNET_R_METRIC%^) is still greater than or equal to that of interface %LAN_IF_IDX% "%LAN_IF_NAME%" ^(%LAN_R_METRIC%^)
  exit /b 1
)

pause
exit /b 0

:: ===========================================================================
:: Subroutines

:CHECKADMIN
:: Check administrative privileges
fsutil dirty query %systemdrive% > nul
if %ERRORLEVEL% LSS 1 exit /b 0
echo  This script must run with "elevated privileges", therefore:
echo    right-click and choose "Run as administrator",
echo    or run it from an elevated console,
echo    or run it from gsudo.
echo.
pause
exit /b 0

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
exit /b 0

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
call :SHOWROUTES
exit /b 0

:GETDEFGW
:: Gets the default gateway of the interfaces
set LAN_DEFGATEWAY=
set INTERNET_DEFGATEWAY=
set count=0
for /f "tokens=1,2,3,4,5*" %%a in ('netsh interface ipv4 show route') do (
  if %%d==0.0.0.0/0 (
    if %%e==%LAN_IF_IDX% (
      set LAN_DEFGATEWAY=%%f
      set /A count+=1
    ) else if %%e==%INTERNET_IF_IDX% (
      set INTERNET_DEFGATEWAY=%%f
      set /A count+=1
    )
  )
  if !count! EQU 2 exit /b 0
)
exit /b 0

:SETPR
:: Get subnets from this file and set permanent local routes 
set DEFGW=%1
echo Setting permanent routes via %DEFGW%:
set status=0
for /f "tokens=1,2 delims=#" %%a in (%THISFILE%) do (
  if %%a==DATA (
    if !status!==1 (
      exit /b 0
    ) else if %%b==subnets (
      set status=1
    ) else if %%b==end (
      exit /b 0
    )
  ) else (
    if !status!==1 (
      echo %%a%%b
      route -p add %%a %DEFGW% 2> nul
    )
  )
)
exit /b 0

:SHOWROUTES
:: Show routes
set count=0
set r=0
for /f "delims=" %%a in ('route -4 print') do (
  set a=%%a
  set a=!a:~0,1!
  if "!a!"=="=" set /A count+=1
  if !count! EQU 3 (
    set /A r+=1
    set a=%%a
    set a=!a: =!
    set a=!a:~0,7!
    set print=1
    if not !r! LEQ 3 if not "!a!"=="0.0.0.0" set print=0
    if !print!==1 echo %%a
  ) else if !count! EQU 4 echo %%a
)
echo.
exit /b 0

:SHOWIF
:: Show interfaces
for /f "delims=" %%a in ('netsh interface ipv4 show interface') do (
  set a=%%a
  set a=!a:~0,3!
  set a=!a: =!
  if !a! EQU %LAN_IF_IDX% (
    echo %ESC%93;40m%%a%ESC%0m
  ) else if !a! EQU %INTERNET_IF_IDX% (
    echo %ESC%92;40m%%a%ESC%0m
  ) else (
    echo %%a
  )
)
set count=0
for /f "delims=" %%a in ('route -4 print') do (
  set a=%%a
  set a=!a:~0,1!
  if "!a!"=="=" set /A count+=1
  if !count! EQU 1 echo %%a
)
echo.
exit /b 0

:SHOWDEFGW
:: Show default gateways
call :GETIFPARM
if "%INTERNET_IF_NAME%"=="" (
  echo Cannot find interface %INTERNET_IF_IDX%
  exit /b 1
)
if %LAN_IF_NAME%=="" (
  echo Cannot find interface %LAN_IF_IDX%
  exit /b 1
)
call :GETDEFGW
if not defined LAN_DEFGATEWAY (
  echo Cannot find default gateway of interface %LAN_IF_IDX% "%LAN_IF_NAME%"
  exit /b 1
)
if not defined INTERNET_DEFGATEWAY (
  echo Cannot find default gateway of interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%"
  exit /b 1
)
echo Current default gateway of interface %LAN_IF_IDX% "%LAN_IF_NAME%" is %LAN_DEFGATEWAY%
echo Current default gateway of interface %INTERNET_IF_IDX% "%INTERNET_IF_NAME%" is %INTERNET_DEFGATEWAY%
exit /b 0

:GETRM
:: Get default route metrics
set LAN_R_METRIC=
set INTERNET_R_METRIC=
set count=0
for /f "tokens=1,2,3,4,5" %%a in ('route -4 print') do (
  if %%a==0.0.0.0 (
    if %%c==%LAN_DEFGATEWAY% (
      set LAN_R_METRIC=%%e
      set /A count+=1
    ) else if %%c==%INTERNET_DEFGATEWAY% (
      set INTERNET_R_METRIC=%%e
      set /A count+=1
    )
  )
  if !count! EQU 2 exit /b 0
)
exit /b 0
