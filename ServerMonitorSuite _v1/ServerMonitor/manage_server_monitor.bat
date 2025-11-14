@echo off
setlocal

rem === Конфигурация ===
set SERVICE_NAME=ServerMonitor
set NSSM_PATH=%~dp0nssm\nssm.exe
set EXE_PATH=%~dp0server_monitor.exe
set STARTUP_DIR=%~dp0
set LOG_DIR=%~dp0logs
set PORT=5000
set RULE_NAME_IN=ServerMonitor-Inbound-TCP-%PORT%
set RULE_NAME_OUT=ServerMonitor-Outbound-TCP-%PORT%

:menu
cls
echo Server Monitor Management Script
echo ===============================
echo 1. Install ServerMonitor service
echo 2. Uninstall ServerMonitor service
echo 3. Check service status
echo 4. Exit
echo ===============================
set /p choice=Select an option (1-4): 

if "%choice%"=="1" goto install
if "%choice%"=="2" goto uninstall
if "%choice%"=="3" goto status
if "%choice%"=="4" goto end
echo Invalid option. Please select 1, 2, 3, or 4.
pause
goto menu

:install
echo Installing %SERVICE_NAME% service...

rem === Проверка и завершение существующих процессов ===
echo Checking for existing server_monitor.exe processes...
tasklist | findstr server_monitor.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Terminating existing server_monitor.exe processes...
    taskkill /IM server_monitor.exe /F >nul 2>&1
    timeout /t 2 /nobreak >nul
)

rem === Создание папки для логов ===
if not exist "%LOG_DIR%" (
    mkdir "%LOG_DIR%"
)

rem === Открытие порта 5000 в брандмауэре ===
echo Checking and creating firewall rules for port %PORT%...
netsh advfirewall firewall show rule name="%RULE_NAME_IN%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    netsh advfirewall firewall add rule name="%RULE_NAME_IN%" dir=in action=allow protocol=TCP localport=%PORT% profile=any
    if %ERRORLEVEL% equ 0 (
        echo Inbound firewall rule for port %PORT% created successfully.
    ) else (
        echo Failed to create inbound firewall rule for port %PORT%.
    )
) else (
    echo Inbound firewall rule for port %PORT% already exists.
)

netsh advfirewall firewall show rule name="%RULE_NAME_OUT%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    netsh advfirewall firewall add rule name="%RULE_NAME_OUT%" dir=out action=allow protocol=TCP localport=%PORT% profile=any
    if %ERRORLEVEL% equ 0 (
        echo Outbound firewall rule for port %PORT% created successfully.
    ) else (
        echo Failed to create outbound firewall rule for port %PORT%.
    )
) else (
    echo Outbound firewall rule for port %PORT% already exists.
)

rem === Удаление службы, если уже существует ===
echo Stopping and deleting existing service...
sc stop %SERVICE_NAME% >nul 2>&1
timeout /t 5 /nobreak >nul
sc delete %SERVICE_NAME% >nul 2>&1

rem === Установка службы через NSSM ===
echo Installing %SERVICE_NAME% service...
"%NSSM_PATH%" install %SERVICE_NAME% "%EXE_PATH%"
if %ERRORLEVEL% neq 0 (
    echo Error installing service. Check NSSM logs.
    goto :end
)
"%NSSM_PATH%" set %SERVICE_NAME% AppDirectory %STARTUP_DIR%
"%NSSM_PATH%" set %SERVICE_NAME% AppStdout "%LOG_DIR%\stdout.log"
"%NSSM_PATH%" set %SERVICE_NAME% AppStderr "%LOG_DIR%\stderr.log"
"%NSSM_PATH%" set %SERVICE_NAME% Start SERVICE_AUTO_START

rem === Запуск службы с повторной попыткой ===
echo Starting %SERVICE_NAME% service...
sc start %SERVICE_NAME%
if %ERRORLEVEL% neq 0 (
    echo First attempt to start service failed. Retrying...
    timeout /t 2 /nobreak >nul
    sc start %SERVICE_NAME%
    if %ERRORLEVEL% neq 0 (
        echo Second attempt failed. Check logs in %LOG_DIR%.
    ) else (
        echo Service started successfully on second attempt.
    )
) else (
    echo Service started successfully on first attempt.
)
pause
goto menu

:uninstall
echo Stopping service and process...
sc stop %SERVICE_NAME% >nul 2>&1

rem Ждём 5 секунд для завершения службы
timeout /t 5 /nobreak >nul

rem Принудительное завершение процесса server_monitor.exe, если он всё ещё работает
tasklist | findstr server_monitor.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Terminating existing server_monitor.exe processes...
    taskkill /IM server_monitor.exe /F >nul 2>&1
    timeout /t 2 /nobreak >nul
)

echo Deleting service...
sc delete %SERVICE_NAME% >nul 2>&1

echo Deleting firewall rules for port %PORT%...
netsh advfirewall firewall delete rule name="%RULE_NAME_IN%" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Inbound firewall rule deleted successfully.
) else (
    echo Inbound firewall rule not found or failed to delete.
)

netsh advfirewall firewall delete rule name="%RULE_NAME_OUT%" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo Outbound firewall rule deleted successfully.
) else (
    echo Outbound firewall rule not found or failed to delete.
)

rem === Удаление папки логов (с попыткой закрыть открытые файлы) ===
if exist "%LOG_DIR%" (
    echo Closing any open log files...
    for %%i in ("%LOG_DIR%\*.log") do (
        if exist "%%i" (
            type nul > "%%i" 2>nul
        )
    )
    rmdir /s /q "%LOG_DIR%"
    if errorlevel 1 (
        echo Warning: Failed to remove log directory. It may be in use.
    ) else (
        echo Log directory %LOG_DIR% removed.
    )
)

echo Done. The %SERVICE_NAME% service, process, and firewall rules have been removed.
exit /b 0
goto menu

:status
echo Checking status of %SERVICE_NAME% service...
sc query %SERVICE_NAME% | findstr "RUNNING" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo The %SERVICE_NAME% service is running.
) else (
    sc query %SERVICE_NAME% >nul 2>&1
    if %ERRORLEVEL% equ 0 (
        echo The %SERVICE_NAME% service is installed but not running.
    ) else (
        echo The %SERVICE_NAME% service is not installed.
    )
)
pause
goto menu

:end
echo Exiting...
exit /b 0