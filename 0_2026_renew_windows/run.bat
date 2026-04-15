@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

cd /d "%~dp0"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "DATESTR=%%i"

set "BACKUP_DIR=%~dp0backup"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

set "LOG_DIR=%~dp0logs"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set "LOG_FILE=%LOG_DIR%\hardening_%DATESTR%.log"
set "KISA_LOG_FILE=%LOG_FILE%"

> "%LOG_FILE%" echo [INFO] KISA Hardening log started: %DATE% %TIME%
>> "%LOG_FILE%" echo [INFO] WorkDir: %CD%
echo [*] Log file: %LOG_FILE%
echo [*] Backup start: %BACKUP_DIR%
>> "%LOG_FILE%" echo [*] Backup start: %BACKUP_DIR%

echo [*] Export local security policy...
secedit /export /cfg "%BACKUP_DIR%\security_policy_%DATESTR%.inf" /areas SECURITYPOLICY USER_RIGHTS >> "%LOG_FILE%" 2>&1

echo [*] Export registry HKLM/HKCU...
reg export HKLM "%BACKUP_DIR%\HKLM_%DATESTR%.reg" /y >> "%LOG_FILE%" 2>&1
reg export HKCU "%BACKUP_DIR%\HKCU_%DATESTR%.reg" /y >> "%LOG_FILE%" 2>&1

echo [*] Export audit policy...
auditpol /backup /file:"%BACKUP_DIR%\auditpol_%DATESTR%.csv" >> "%LOG_FILE%" 2>&1

echo [*] Export user/group info...
net user > "%BACKUP_DIR%\users_%DATESTR%.txt" 2>> "%LOG_FILE%"
net localgroup administrators > "%BACKUP_DIR%\administrators_%DATESTR%.txt" 2>> "%LOG_FILE%"

echo [*] Export firewall rules...
netsh advfirewall export "%BACKUP_DIR%\firewall_%DATESTR%.wfw" >> "%LOG_FILE%" 2>&1

echo [*] Backup complete
>> "%LOG_FILE%" echo [*] Backup complete

echo [*] Running hardening script...
>> "%LOG_FILE%" echo [*] Running hardening script...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0hardening.ps1"
set "PS_ERR=%errorlevel%"
>> "%LOG_FILE%" echo [INFO] PowerShell exit code: %PS_ERR%

echo.
if %PS_ERR% NEQ 0 (
  echo [ERROR] PowerShell script failed with exit code %PS_ERR%
  >> "%LOG_FILE%" echo [ERROR] PowerShell script failed with exit code %PS_ERR%
  echo [INFO] Check log file: %LOG_FILE%
  pause
  exit /b %PS_ERR%
)

echo [INFO] Hardening complete.
echo [INFO] System will reboot in 10 seconds.
>> "%LOG_FILE%" echo [INFO] Hardening complete, reboot in 10 seconds.
shutdown /r /t 10 /c "Security hardening applied - auto reboot in 10 seconds"
exit /b 0
