@echo off

echo �������������������� W-60. SNMP ���� ���� ���� >> %FILENAME%
net start | findstr /I "SNMP" > nul

if errorlevel 1 ( 
	echo. >> %FILENAME%
	echo �� ��� : ��ȣ, SNMP ���񽺰� ��Ȱ��ȭ �Ǿ� ����		>> %FILENAME%
) else (
	echo. >> %FILENAME%
	echo �� ��� : ���, SNMP ���񽺰� ��������		>> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ	>> %FILENAME%
echo. >> %FILENAME%
net start | findstr /I "SNMP"	>> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%