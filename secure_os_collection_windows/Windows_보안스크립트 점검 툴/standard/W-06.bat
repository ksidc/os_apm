@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-06. 관리자 그룹에 최소한의 사용자 포함 >> %FILENAME%
echo. >> %FILENAME%
echo ■ 결과 : 수동점검, 불필요한 관리자 계정이 존재하는지 확인 >> %FILENAME%
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
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [관리자 그룹 계정 목록] >> %FILENAME%
type %TEMP%\Admin_account.txt >> %FILENAME%

echo. >> %FILENAME%
echo [관리자 계정 정보] >> %FILENAME%
type %TEMP%\Admin_account_info.txt >> %FILENAME%

echo.	>> %FILENAME%
echo ** 설명 :  상기 확인 된 계정 중 불필요한 계정 확인 >> %FILENAME%

echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%