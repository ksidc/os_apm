@echo off

echo �������������������� W-01. Administrator ���� �̸� ���� �Ǵ� ���ȼ� ��ȭ >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "NewAdministratorName" >> %TEMP%\Admin_name.txt
type %CONFIG%Security_Policy.txt | find /i "EnableAdminAccount" >> %TEMP%\Admin_enable.txt
type %TEMP%\Admin_name.txt | Tools\awk.exe -F= "{print $2}"| findstr /i "Administrator" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, administrator �������� �����Ͽ� ����ϰ� ���� >> %FILENAME%
) else (
	type %TEMP%\Admin_enable.txt | find "1" > nul
	if errorlevel 1 (
		echo �� ��� : ��ȣ, administrator ������ ������� ���� >> %FILENAME%
	) else (
		echo �� ��� : ���, administrator �Ǵ� Admin �������� ����ϰ� ���� >> %FILENAME%
	)
)
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Admin_name.txt >> %FILENAME%
type %TEMP%\Admin_enable.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
