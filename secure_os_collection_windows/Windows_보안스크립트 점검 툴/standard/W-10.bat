@echo off

echo �������������������� W-10. IIS ���� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

if %IIS_RUN% EQU 0 (
	echo �� ��� : ��ȣ, IIS ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - IIS ���񽺰� ���� ������ ���� >> %FILENAME%
) 
if %IIS_RUN% EQU 1 (
	echo �� ��� : ��������, IIS ���񽺸� ���� ���̹Ƿ� �ʿ信 ���Ͽ� ��� ������ Ȯ�� �ʿ� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %CONFIG%Net_Start.txt | find /i "World Wide Web Publishing" >> %FILENAME%
	echo. >> %FILENAME%
	sc query W3SVC | findstr /i "W3SVC STATE" >> %FILENAME%
	echo. >> %FILENAME%
	echo [IIS ����] >> %FILENAME%
	reg query "HKLM\SOFTWARE\Microsoft\InetStp" | findstr /i "SetupString" >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%