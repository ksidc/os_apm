@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-82. Windows 인증 모드 사용		>> %FILENAME%
echo.	>> %FILENAME%

net start | find /i "SQL Server" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호			>> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo MS-SQL Server 서비스가 구동 중이지 않음 >> %FILENAME%
) else (
	reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server" /s | find /i "LoginMode" | find "2" > nul
	if errorlevel 1 (
		echo ■ 결과 : 양호, Windows 인증모드를 사용하고 있음 >> %FILENAME%
	) else (
		echo ■ 결과 : 취약, 혼합 인증모드를 사용하고 있음 >> %FILENAME%
	)
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SQL Server" /s | find /i "LoginMode" >> %FILENAME%
)

echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo. 	>> %FILENAME%