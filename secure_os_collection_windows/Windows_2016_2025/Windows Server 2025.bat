@echo off
chcp 65001>nul & setlocal enabledelayedexpansion
rem ������������������������������������������������������������������������������������
rem  Windows Server ���� ���� �ڵ�ȭ ��ġ
rem ������������������������������������������������������������������������������������

rem ���� BAT ��ġ�� �̵�
cd /d "%~dp0"

:: ���� ��ġ ���� ��ġ ���� ��� ���� ����
set "BACKUP_DIR=%~dp0backup"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

echo [*] ��� ����: %BACKUP_DIR%
set "DATESTR=%DATE:~0,4%%DATE:~5,2%%DATE:~8,2%_%TIME:~0,2%%TIME:~3,2%"
set "DATESTR=%DATESTR: =0%"

:: 1. ���� ���� ��å ���
echo [*] ���� ���� ��å ��� ��...
secedit /export /cfg "%BACKUP_DIR%\security_policy_%DATESTR%.inf" /areas SECURITYPOLICY USER_RIGHTS >nul 2>&1

:: 2. ��ü ������Ʈ�� ��� (HKLM, HKCU, HKU, HKCR, HKCC)
echo [*] ��ü ������Ʈ�� ��� ��... (�ణ �ð� �ҿ�)
reg export HKLM "%BACKUP_DIR%\HKLM_%DATESTR%.reg" /y >nul 2>&1
reg export HKCU "%BACKUP_DIR%\HKCU_%DATESTR%.reg" /y >nul 2>&1
reg export HKU  "%BACKUP_DIR%\HKU_%DATESTR%.reg"  /y >nul 2>&1
reg export HKCR "%BACKUP_DIR%\HKCR_%DATESTR%.reg" /y >nul 2>&1
reg export HKCC "%BACKUP_DIR%\HKCC_%DATESTR%.reg" /y >nul 2>&1

:: 3. ���� ��å ���
echo [*] ���� ��å ��� ��...
auditpol /backup /file:"%BACKUP_DIR%\auditpol_%DATESTR%.csv"

:: 4. ����� �� �׷� ���� ���
echo [*] �����/�׷� ���� ��� ��...
net user > "%BACKUP_DIR%\users_%DATESTR%.txt"
net localgroup administrators > "%BACKUP_DIR%\administrators_%DATESTR%.txt"

rem ���� ������å(CurrentUser) ���
for /f "delims=" %%a in ('
  powershell -NoProfile -Command "Get-ExecutionPolicy -Scope CurrentUser"
') do set "OLDPOLICY=%%a"
if "%OLDPOLICY%"=="" set "OLDPOLICY=Undefined"

rem PowerShell ��ũ��Ʈ ���� (��å ���� ���� Bypass ���)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Windows Server 2025.ps1"
set "PS_ERR=%errorlevel%"

rem ������å ����
if /i "%OLDPOLICY%"=="Undefined" (
  powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser Undefined -Force"
) else (
  powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser %OLDPOLICY% -Force"
)

echo.
if %PS_ERR% NEQ 0 (
  echo [����] PowerShell ��ũ��Ʈ�� ���� �ڵ� %PS_ERR% �� ����Ǿ����ϴ�.
  pause
  exit /b %PS_ERR%
)

echo [�ȳ�] ���� ���� ������ �Ϸ�Ǿ����ϴ�. (������å: %OLDPOLICY% �� ����)
echo ������� �ʿ��� �׸��� ���ԵǾ� �ֽ��ϴ�.

choice /c YN /n /m "���� ������Ͻðڽ��ϱ�? (Y/N): "
if errorlevel 2 (
  echo ������� ����߽��ϴ�.
  exit /b 0
)

shutdown /r /t 30 /c "Windows Server ���� ���� ���� ? 30�� �� �ڵ� �����"
exit /b 0
