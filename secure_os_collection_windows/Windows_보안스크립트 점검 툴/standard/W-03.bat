@echo off

echo �������������������� W-03. ���ʿ��� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

echo �� ��� : ��������, ���ʿ��� ���� ���� ���� ���� >> %FILENAME%
wmic useraccount get name | findstr /v /i "Name" > %TEMP%\User_name.txt

FOR /F "tokens=1,2,3" %%j IN (%TEMP%\User_name.txt) DO (
	IF %%j GTR "" (
		net user %%j | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active.txt
			net user %%j >> %CONFIG%User_active.txt
		) else (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active_no.txt
			net user %%j >> %CONFIG%User_active_no.txt
		)
	)
	IF %%k GTR "" (
		net user %%k | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active.txt
			net user %%k >> %CONFIG%User_active.txt
		) else (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active_no.txt
			net user %%k >> %CONFIG%User_active_no.txt
		)
	)
	IF %%l GTR "" (
		net user %%l | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active.txt
			net user %%l >> %CONFIG%User_active.txt
		) else (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active_no.txt
			net user %%l >> %CONFIG%User_active_no.txt
		)
	)
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [����� ���� ���] >> %FILENAME%
type %TEMP%\User_name.txt >> %FILENAME%
echo [������ �н����� ���� ���� Ȯ��] >> %FILENAME%
type %CONFIG%User_active.txt | findstr /i "\----- Name Last" | find /i /v "Full" >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo �� �� ���� ������ %CONFIG%User_active.txt ���� ���� >> %FILENAME%

echo. >> %FILENAME%
echo ** ���� :  ��� Ȯ�� �� ���� �� ���ʿ��� ���� Ȯ�� >> %FILENAME%
echo (DefaultAccount, Guest, WDAGUtilityAccount�� �⺻ ����)  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%