@echo off

echo �������������������� W-46. Everyone ��� ������ �͸� ����ڿ� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "EveryoneIncludesAnonymous" | Tools\awk.exe -F\ "{print $6}" >> %TEMP%\Everyone_Anonymous.txt
FOR /f "tokens=2 delims=," %%e IN (%TEMP%\Everyone_Anonymous.txt) DO set E_AM=%%e

if %E_AM% EQU 0 echo �� ��� : ��ȣ, 'Everyone ��� ������ �͸� ����ڿ��� ����' ��å�� '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
if %E_AM% EQU 1 echo �� ��� : ���, 'Everyone ��� ������ �͸� ����ڿ��� ����' ��å�� '���'���� �����Ǿ� ���� >> %FILENAME%

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Everyone_Anonymous.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� ��� �� ��: 4,0 / ���: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%