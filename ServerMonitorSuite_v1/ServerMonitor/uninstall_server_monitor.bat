@echo off
setlocal

rem === Конфигурация ===
set SERVICE_NAME=ServerMonitor
set PORT=5000
set RULE_NAME_IN=ServerMonitor-Inbound-TCP-%PORT%
set RULE_NAME_OUT=ServerMonitor-Outbound-TCP-%PORT%
set LOG_DIR=%~dp0logs

echo Stopping service and process...
rem Остановка службы
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