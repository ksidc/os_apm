@echo off

echo �������������������� W-30. RDS(Remote Data Services)���� >> %FILENAME%
echo. >> %FILENAME%

if %IIS_RUN% EQU 0 (
	echo �� ��� : ��ȣ, IIS ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - IIS ���񽺰� ���� ������ ���� >> %FILENAME%
) else (
	echo �� ��� : ��ȣ, Windows Server 2008 �̻� ���������� �ش� �׸��� ������� �������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo [Windows ����] >> %FILENAME%
	type %CONFIG%System_Info.txt | find /i "OS" | findstr /i "Name Version" | findstr /i /v "Host BIOS" >> %FILENAME%
	echo. >> %FILENAME%
	echo �� Windows 2000 Service Pack 4, Windows 2003 Service Pack 2, Windows 2008 �̻� ��ġ�Ǿ� �ִ� ��� ��ȣ >> %FILENAME%
	echo    �� �������� ���� ������ Windows�� ����ϰ� �ִ� ��� ���� ���� �ʿ� >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%