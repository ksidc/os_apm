@echo off

echo �������������������� W-04. ���� ��� �Ӱ谪 ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "LockoutBadCount" >> %TEMP%\Lockout_badcount.txt
FOR /f "tokens=3" %%a IN (%Temp%\Lockout_badcount.txt) DO set L_BAD=%%a

if %L_BAD% EQU 0 (
	echo �� ��� : ���, ���� ��� �Ӱ谪�� �������� ���� >> %FILENAME%
) else (
	if %L_BAD% LEQ 5 (
		echo �� ��� : ��ȣ, ���� ��� �Ӱ谪�� 5 ������ ������ �����Ǿ� ���� >> %FILENAME%
	) else (
		echo �� ��� : ���, ���� ��� �Ӱ谪�� 5�� �ʰ��ϴ� ������ �����Ǿ� ���� >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Lockout_badcount.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo �� ���� ���� �׸�: W-47 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%