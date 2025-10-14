@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-01. Administrator 계정 이름 변경 또는 보안성 강화 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "NewAdministratorName" >> %TEMP%\Admin_name.txt
type %CONFIG%Security_Policy.txt | find /i "EnableAdminAccount" >> %TEMP%\Admin_enable.txt
type %TEMP%\Admin_name.txt | Tools\awk.exe -F= "{print $2}"| findstr /i "Administrator" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, administrator 계정명을 변경하여 사용하고 있음 >> %FILENAME%
) else (
	type %TEMP%\Admin_enable.txt | find "1" > nul
	if errorlevel 1 (
		echo ■ 결과 : 양호, administrator 계정을 사용하지 않음 >> %FILENAME%
	) else (
		echo ■ 결과 : 취약, administrator 또는 Admin 계정명을 사용하고 있음 >> %FILENAME%
	)
)
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Admin_name.txt >> %FILENAME%
type %TEMP%\Admin_enable.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
