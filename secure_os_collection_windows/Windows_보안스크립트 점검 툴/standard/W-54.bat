@echo off

echo �������������������� W-54. �͸� SID/�̸� ��ȯ ���                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "LSAAnonymousNameLookup" | Find "0"  > nul
if errorlevel 1 (
	echo �� ��� : ���, ���͸� SID/�̸� ��ȯ ��롱 ��å�� ����롱 ���� �Ǿ� ����						>> %FILENAME%
) else (
	echo �� ��� : ��ȣ, ���͸� SID/�̸� ��ȯ ��롱 ��å�� ����� �� �ԡ� ���� �Ǿ� ����					>> %FILENAME%
)
echo.                              >> %FILENAME%
echo �� �� ��Ȳ                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "LSAAnonymousNameLookup"          >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
