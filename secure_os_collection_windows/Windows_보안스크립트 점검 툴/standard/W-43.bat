@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-43. Autologon 기능 제어 >> %FILENAME%
echo. >> %FILENAME%

reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" | find /i "AutoAdminLogon" >> %TEMP%\Auto_admin_logon.txt

type %TEMP%\Auto_admin_logon.txt | find /i "AutoAdminLogon" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, AutoAdminLogon 값이 존재하지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - 해당 레지스트리 값이 존재하지 않음 >> %FILENAME%
) else (
	type %TEMP%\Auto_admin_logon.txt | find "0" > nul
	if errorlevel 1 (
		echo ■ 결과 : 취약, AutoAdminLogon 값이 1로 설정되어 있음 >> %FILENAME%
	) else (
		echo ■ 결과 : 양호, AutoAdminLogon 값이 0으로 설정되어 있음 >> %FILENAME%
	)
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\Auto_admin_logon.txt >> %FILENAME%	
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%