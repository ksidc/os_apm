@echo off

echo �������������������� W-50. �н����� �ִ� ��� �Ⱓ >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "MaximumPasswordAge" >> %TEMP%\Password_maxage.txt
FOR /f "tokens=3" %%h IN (%Temp%\Password_maxage.txt) DO set P_MAX=%%h

if %P_MAX% LEQ 90 (
	if %P_MAX% EQU 0 (
		echo �� ��� : ���, �ִ� ��ȣ ��� �Ⱓ�� �������� ���� >> %FILENAME%
	) else (
		echo �� ��� : ��ȣ, �ִ� ��ȣ ��� �Ⱓ�� 90�� ���Ϸ� �����Ǿ� ���� >> %FILENAME%
	)
) else (
	echo �� ��� : ���, �ִ� ��ȣ ��� �Ⱓ�� 90���� �ʰ��Ͽ� �����Ǿ� ���� >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Password_maxage.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%