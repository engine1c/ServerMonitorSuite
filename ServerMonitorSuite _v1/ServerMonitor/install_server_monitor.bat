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

:end
pause