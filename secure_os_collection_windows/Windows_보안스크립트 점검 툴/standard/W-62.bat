@echo off

echo �������������������� W-62. SNMP Access Control ���� >> %FILENAME%
echo. >> %FILENAME%	
net start | findstr /I "SNMP" > nul
if errorlevel 1 ( 
	echo �� ��� : ��ȣ, SNMP ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo SNMP ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
) else (
	reg query "HKLM\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" | findstr "1"  > nul
	if errorlevel 1 (
		echo �� ��� : ���, SNMP ACL�� �������� ���� >> %FILENAME%
	) else (
		echo �� ��� : ��ȣ, SNMP ACL�� �����Ǿ� ���� >> %FILENAME%
	)
	echo. >> %FILENAME%
	echo �� �� ��Ȳ		>> %FILENAME%
	echo. >> %FILENAME%
	reg query "HKLM\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers" | findstr /i /v "SNMP\Parameters\PermittedManagers" >> %FILENAME% 2>&1
)
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%