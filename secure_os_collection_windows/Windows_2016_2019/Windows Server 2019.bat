@echo off
REM ���� BAT ������ ��ġ�� ������ �̵�
cd /d %~dp0

REM ���� ������å(CurrentUser ������)�� ����
for /f "delims=" %%a in ('powershell -NoProfile -Command "Get-ExecutionPolicy -Scope CurrentUser"') do set OLDPOLICY=%%a

REM �Ͻ������� ������å�� CurrentUser �������� ���� (������ ���� ���ʿ�)
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force"

REM Windows Server 2019.ps1 ���� (��� ���� �߿�)
powershell -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Windows Server 2019.ps1"

REM ������å(CurrentUser ������) ���󺹱�
powershell -NoProfile -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy %OLDPOLICY% -Force"

echo.
echo [�ȳ�] Windows Server 2019.ps1 ���� �Ϸ�. ���� ��å(CurrentUser ������)�� [%OLDPOLICY%]�� �����߽��ϴ�.
echo ������� �ʿ��� ������ ����Ǿ����ϴ�.
echo.
set /p REBOOT=����Ϸ��� [Enter] Ű�� ��������. (������ ��� ����õ˴ϴ�)

REM ����� ����
shutdown /r /t 0