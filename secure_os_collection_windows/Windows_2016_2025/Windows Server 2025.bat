@echo off
chcp 65001>nul & setlocal enabledelayedexpansion
rem ������������������������������������������������������������������������������������
rem  Windows Server ���� ���� �ڵ�ȭ ��ġ
rem ������������������������������������������������������������������������������������

rem ���� BAT ��ġ�� �̵�
cd /d "%~dp0"

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
