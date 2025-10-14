@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-65. Telnet 보안 설정 >> %FILENAME%
echo.	>> %FILENAME%
net start | findstr /I "Telnet"	> nul

if errorlevel 1 (
	echo ■ 결과 : 양호, Telnet 서비스가 비활성화되어 있음		 >> %FILENAME%
	echo "Telnet 서비스가 비활성화 되어 있음"	>> %TEMP%\Telnet_Auth_Met.txt
) else (
	tlntadmn config	>> %TEMP%\Telnet_Auth_Met.txt
	type %TEMP%\Telnet_Auth_Met.txt | findstr /I "Authentication" 	> nul
	type %TEMP%\Telnet_Auth_Met.txt | findstr /I "password" 		> nul
	if errorlevel 1 (
		echo ■ 결과 : 양호		 >> %FILENAME%
	) else (
		echo ■ 결과 : 취약		 >> %FILENAME%
	)
)
echo.	>> %FILENAME%
echo ■ 상세 현황		 >> %FILENAME%
echo.	>> %FILENAME%
type %TEMP%\Telnet_Auth_Met.txt | findstr /I "Authentication" 	 >> %FILENAME%	
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%