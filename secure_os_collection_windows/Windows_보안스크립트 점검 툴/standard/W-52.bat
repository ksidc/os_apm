@echo off

echo �������������������� W-52. ������ ����� �̸� ǥ�� ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "DontDisplayLastUserName" | Tools\awk.exe -F\ "{print $8}" >> %TEMP%\Display_lastuser.txt
FOR /f "tokens=2 delims=," %%j IN (%TEMP%\Display_lastuser.txt) DO set D_LAST=%%j

if %D_LAST% EQU 0 echo �� ��� : ���, '������ ����� �̸� ǥ�� �� ��' ��å�� '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
if %D_LAST% EQU 1 echo �� ��� : ��ȣ, '������ ����� �̸� ǥ�� �� ��' ��å�� '���'���� �����Ǿ� ���� >> %FILENAME%

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Display_lastuser.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� ��� �� ��: 4,0 / ���: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%