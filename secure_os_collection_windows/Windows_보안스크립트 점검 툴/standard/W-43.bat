@echo off

echo �������������������� W-43. Autologon ��� ���� >> %FILENAME%
echo. >> %FILENAME%

reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | find /i "AutoAdminLogon" >> %TEMP%\Auto_admin_logon.txt

type %TEMP%\Auto_admin_logon.txt | find /i "AutoAdminLogon" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, AutoAdminLogon ���� �������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - �ش� ������Ʈ�� ���� �������� ���� >> %FILENAME%
) else (
	type %TEMP%\Auto_admin_logon.txt | find "0" > nul
	if errorlevel 1 (
		echo �� ��� : ���, AutoAdminLogon ���� 1�� �����Ǿ� ���� >> %FILENAME%
	) else (
		echo �� ��� : ��ȣ, AutoAdminLogon ���� 0���� �����Ǿ� ���� >> %FILENAME%
	)
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\Auto_admin_logon.txt >> %FILENAME%	
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%