@echo off

echo �������������������� W-49. �н����� �ּ� ��ȣ ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "MinimumPasswordLength" >> %TEMP%\Password_minlen.txt
FOR /f "tokens=3" %%g IN (%Temp%\Password_minlen.txt) DO set P_LEN=%%g

if %P_LEN% GEQ 8 (
	echo �� ��� : ��ȣ, �ּ� ��ȣ ���̰� 8���� �̻����� �����Ǿ� ���� >> %FILENAME%
) else (
	if %P_LEN% EQU 0 (
		echo �� ��� : ���, '��ȣ �ʿ� ����'���� �����Ǿ� ���� >> %FILENAME%
	) else (
		echo �� ��� : ���, �ּ� ��ȣ ���̰� 8���� �̸����� �����Ǿ� ���� >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Password_minlen.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%