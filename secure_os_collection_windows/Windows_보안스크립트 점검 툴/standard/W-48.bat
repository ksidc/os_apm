@echo off

echo �������������������� W-48. �н����� ���⼺ ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "PasswordComplexity" >> %TEMP%\Password_complex.txt
FOR /f "tokens=3" %%f IN (%Temp%\Password_complex.txt) DO set P_COM=%%f

if %P_COM% EQU 0 echo �� ��� : ���, '��ȣ�� ���⼺�� �����ؾ� ��' ��å�� '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
if %P_COM% EQU 1 echo �� ��� : ��ȣ, '��ȣ�� ���⼺�� �����ؾ� ��' ��å�� '���'���� �����Ǿ� ���� >> %FILENAME%

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Password_complex.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%