@echo off

echo �������������������� W-66. ���ʿ��� ODBC/OLE-DB ������ �ҽ��� ����̺� ���� >> %FILENAME%
echo. >> %FILENAME%
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\ODBC\ODBC.ini\ODBC Data Sources" /s	> %TEMP%\ODB_TEMP.txt
type %TEMP%\ODB_TEMP.txt | find /i "ODBC" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - ���ʿ��� ������ �ҽ� �� ����̺갡 �������� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, ���ʿ��� ������ �ҽ� �� ����̺����� Ȯ�� �ʿ� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\ODB_TEMP.txt >> %FILENAME%
)
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%