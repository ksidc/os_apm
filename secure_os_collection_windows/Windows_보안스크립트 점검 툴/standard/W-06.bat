@echo off

echo �������������������� W-06. ������ �׷쿡 �ּ����� ����� ���� >> %FILENAME%
echo. >> %FILENAME%
echo �� ��� : ��������, ���ʿ��� ������ ������ �����ϴ��� Ȯ�� >> %FILENAME%
net localgroup Administrators >> %CONFIG%localgroup_administrators.txt
type %CONFIG%localgroup_administrators.txt | findstr /v "Comment Members completed" | findstr /v /i "Alias -----" | findstr . >> %TEMP%\Admin_account.txt

FOR /F "tokens=1,2,3" %%j IN (%TEMP%\Admin_account.txt) DO (
	IF %%j GTR "" (
		echo -----------------------------------------------------------------------  >> %TEMP%\Admin_account_info.txt
		net user %%j | findstr /i "name Account logon" | findstr /v /i "Comment full script allowed" >> %TEMP%\Admin_account_info.txt
	)
	IF %%k GTR "" (
		echo -----------------------------------------------------------------------  >> %TEMP%\Admin_account_info.txt
		net user %%k | findstr /i "name Account logon" | findstr /v /i "Comment full script allowed" >> %TEMP%\Admin_account_info.txt
	)
	IF %%l GTR "" (
		echo -----------------------------------------------------------------------  >> %TEMP%\Admin_account_info.txt
		net user %%l | findstr /i "name Account logon" | findstr /v /i "Comment full script allowed" >> %TEMP%\Admin_account_info.txt
	)
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [������ �׷� ���� ���] >> %FILENAME%
type %TEMP%\Admin_account.txt >> %FILENAME%

echo. >> %FILENAME%
echo [������ ���� ����] >> %FILENAME%
type %TEMP%\Admin_account_info.txt >> %FILENAME%

echo.	>> %FILENAME%
echo ** ���� :  ��� Ȯ�� �� ���� �� ���ʿ��� ���� Ȯ�� >> %FILENAME%

echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%