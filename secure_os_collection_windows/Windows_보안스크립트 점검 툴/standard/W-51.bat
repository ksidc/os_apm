@echo off

echo �������������������� W-51. �н����� �ּ� ��� �Ⱓ >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "MinimumPasswordAge" >> %TEMP%\Password_minage.txt
FOR /f "tokens=3" %%i IN (%Temp%\Password_minage.txt) DO set P_MIN=%%i

if %P_MIN% EQU 0 echo �� ��� : ���, �ּ� ��ȣ ��� �Ⱓ�� �������� ���� >> %FILENAME%
if %P_MIN% GEQ 1 echo �� ��� : ��ȣ, �ּ� ��ȣ ��� �Ⱓ�� 1�� �̻����� �����Ǿ� ���� >> %FILENAME%

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Password_minage.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
