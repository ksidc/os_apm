@echo off

echo �������������������� W-47. ���� ��� �Ⱓ ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_policy.txt | findstr /i "LockoutDuration ResetLockoutCount" >> %TEMP%\Lockout_Duration_Reset.txt

for %%f in (%TEMP%\Lockout_Duration_Reset.txt) do (
	if %%~zf EQU 0 (
		echo �� ��� : ���, ���� ��� �Ⱓ �� �����ð� �� ���� ��� ���� ������� ������ �������� ���� >> %FILENAME%
		echo. >> %FILENAME%
		echo �� �� ��Ȳ >> %FILENAME%
		echo. >> %FILENAME%
		echo - LockoutDuration, ResetLockoutCount ���� �������� ���� >> %FILENAME%
	) else (
		echo �� ��� : ��������, ���� ��� �Ⱓ �� ��� ���� �Ⱓ�� �����ϰ� ���� >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Lockout_Duration_Reset.txt >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �ֿ�������ű�ݽü� ���̵� ����, ���� ��� �� �����ð� �� ���� ��� ���� ������� ����: 60�� �̻� �ǰ� >> %FILENAME%
			echo - LockoutDuration=0�� ��� �����ڰ� ��������� ����� ������ ������ ��� ���·� ������ >> %FILENAME%
		)
	)
)

echo. >> %FILENAME%
echo ** ���� :   ��� �� ���� �׸� 60 �̸� ��ȣ  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%