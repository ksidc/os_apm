@echo off

echo �������������������� W-25. FTP ���� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

if %FTP_RUN% EQU 0 (
	echo �� ��� : ��ȣ, FTP ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - FTP ���񽺰� ���� ������ ���� >> %FILENAME%
) else (
	echo �� ��� : ���, FTP ���񽺰� Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %CONFIG%Net_Start.txt | findstr /i "ftp" >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%