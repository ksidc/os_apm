@echo off

echo �������������������� W-56. �ܼ� �α׿� �� ���� �������� �� ��ȣ ��� ����                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "LimitBlankPasswordUse" | find "4,1"  > nul
if errorlevel 1 (
	echo �� ��� : ���, ���ܼ� �α׿� �� ���� �������� �� ��ȣ ��� ���ѡ� ��å�� ����� �� �ԡ����� �Ǿ� ����          >> %FILENAME%
) else (
	echo �� ��� : ��ȣ, ���ܼ� �α׿� �� ���� �������� �� ��ȣ ��� ���ѡ� ��å�� ����롱���� �Ǿ� ����          >> %FILENAME%
)
echo.                              >> %FILENAME%
echo �� �� ��Ȳ                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "LimitBlankPasswordUse"	| Tools\awk.exe -F\ "{print $6}"          >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%