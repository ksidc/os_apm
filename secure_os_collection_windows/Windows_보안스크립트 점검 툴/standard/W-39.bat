@echo off

echo �������������������� W-39. �α׿� ���� �ʰ� �ý��� ���� ��� >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "ShutdownWithoutLogon" | Tools\awk.exe -F\ "{print $8}" >> %TEMP%\Shutdown_without.txt
FOR /f "tokens=2 delims=," %%s IN (%TEMP%\Shutdown_without.txt) DO set W_LOGON=%%s

if %W_LOGON% EQU 0 echo �� ��� : ��ȣ, '�α׿� ���� �ʰ� �ý��� ���� ���' ��å�� '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
if %W_LOGON% EQU 1 echo �� ��� : ���, '�α׿� ���� �ʰ� �ý��� ���� ���' ��å�� '���'���� �����Ǿ� ���� >> %FILENAME%	

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Shutdown_without.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� ��� �� ��: 4,0 / ���: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%