@echo off

echo �������������������� W-82. Windows ���� ��� ���		>> %FILENAME%
echo.	>> %FILENAME%

net start | find /i "SQL Server" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ			>> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo MS-SQL Server ���񽺰� ���� ������ ���� >> %FILENAME%
) else (
	reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server" /s | find /i "LoginMode" | find "2" > nul
	if errorlevel 1 (
		echo �� ��� : ��ȣ, Windows ������带 ����ϰ� ���� >> %FILENAME%
	) else (
		echo �� ��� : ���, ȥ�� ������带 ����ϰ� ���� >> %FILENAME%
	)
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server" /s | find /i "LoginMode" >> %FILENAME%
)

echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo. 	>> %FILENAME%