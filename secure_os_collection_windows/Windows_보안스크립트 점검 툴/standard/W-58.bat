@echo off

echo �������������������� W-58. �͹̳� ���� ��ȣȭ ���� ����                              >> %FILENAME%
echo.                              >> %FILENAME%

type Config\%COMPUTERNAME%_Net_Start.txt | find /I "Remote Desktop Services" | find /V "UserMode Port Redirector"  > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ���� ����ũž ���񽺰� ���� ������ �ʽ��ϴ�.                      >> %FILENAME%
	echo.                              >> %FILENAME%
	echo �� �� ��Ȳ                              >> %FILENAME%
	echo.                              >> %FILENAME%
	type Config\%COMPUTERNAME%_Net_Start.txt | find /I "Remote Desktop Services" | find /V "UserMode Port Redirector"         >> %FILENAME%
	goto W-58_END
)
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server"          > %TEMP%\terminal_temp.txt
type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup" | find "1"  > nul
if errorlevel 1 (
	goto Enable_rdp
) else (
	echo �� ��� : ��ȣ, ���� ����ũž ���񽺰� ���� ���̳�, ������ ������ �������� �����Ǿ� ����                    >> %FILENAME%
	echo.                              >> %FILENAME%
	echo �� �� ��Ȳ                              >> %FILENAME%
	echo.                              >> %FILENAME%
	type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup" | find "1"          >> %FILENAME%
	goto W-58_END
)
	

:2012_Enable_rdp
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" | find /I "MinEncryptionLevel"  > nul
if errorlevel 1 (
	goto Enable_rdp
)
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" | find /I "MinEncryptionLevel"     > %TEMP%\Terminal_level.txt
FOR /F "tokens=3" %%k in (%TEMP%\Terminal_level.txt) do SET Terminal_level=%%k
if %Terminal_level% GEQ 2 (
	echo �� ��� : ��ȣ, �͹̳� ���� ��ȣȭ ������ Ŭ���̾�Ʈ�� ȣȯ ����[�߰�] �̻����� �����ϰ� ����		>> %FILENAME%
) else (
	echo �� ��� : ���, �͹̳� ���� ��ȣȭ ������ �������� �����Ǿ� ����          >> %FILENAME%
)
echo.                              >> %FILENAME%
echo �� �� ��Ȳ                              >> %FILENAME%
echo.                              >> %FILENAME%
echo [���� �͹̳� ���� ��ȣȭ ���� ����]                              >> %FILENAME%
type %TEMP%\Terminal_level.txt                              >> %FILENAME%
if %Terminal_level%==1 set level_info=(���� ����)          >> %FILENAME%
if %Terminal_level%==2 set level_info=(�߰� ����, Ŭ���̾�Ʈ�� ȣȯ ����)          >> %FILENAME%
if %Terminal_level%==3 set level_info=(���� ����)          >> %FILENAME%
echo ��ȣȭ ���� : %Terminal_level% %level_info%          >> %FILENAME%

goto W-58_END


:Enable_rdp
reg query "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Terminal Server\WinStations\RDP-Tcp" | find /I "MinEncryptionLevel"     > %TEMP%\Terminal_level.txt
FOR /F "tokens=3" %%k in (%TEMP%\Terminal_level.txt) do SET Terminal_level=%%k
if %Terminal_level% GEQ 2 (
	echo �� ��� : ��ȣ, �͹̳� ���� ��ȣȭ ������ Ŭ���̾�Ʈ�� ȣȯ ����[�߰�] �̻����� �����ϰ� ����		>> %FILENAME%
) else (
	echo �� ��� : ���, �͹̳� ���� ��ȣȭ ������ �������� �����Ǿ� ����          >> %FILENAME%
)
echo.                              >> %FILENAME%
echo �� �� ��Ȳ                              >> %FILENAME%
echo.                              >> %FILENAME%
echo [�����͹̳� ���� ��ȣȭ ���� ����]                              >> %FILENAME%
type %TEMP%\Terminal_level.txt                              >> %FILENAME%
if %Terminal_level%==1 set level_info=(���� ����)          >> %FILENAME%
if %Terminal_level%==2 set level_info=(�߰� ����, Ŭ���̾�Ʈ�� ȣȯ ����)          >> %FILENAME%
if %Terminal_level%==3 set level_info=(���� ����)          >> %FILENAME%
echo ��ȣȭ ���� : %Terminal_level% %level_info%          >> %FILENAME%

:W-58_END
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%


