@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-75. 경고 메시지 설정	>> %FILENAME%
echo.	>> %FILENAME%
echo [로그인 배너 제목]		> %TEMP%\WINLOGIN_BANN.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "legalnoticecaption" | Tools\awk.exe -F\ "{print $8}"	>> %TEMP%\WINLOGIN_BANN.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "legalnoticecaption" > nul
if errorlevel 1 (
	echo legalnoticecaption[배너 제목] 값이 존재하지 않습니다.	>> %TEMP%\WINLOGIN_BANN.txt
)
echo .					>> %TEMP%\WINLOGIN_BANN.txt
echo [로그인 배너 본문]		>> %TEMP%\WINLOGIN_BANN.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "legalnoticetext" | Tools\awk.exe -F\ "{print $8}"		>> %TEMP%\WINLOGIN_BANN.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "legalnoticetext" > nul
if errorlevel 1 (
	echo legalnoticetext[배너 본문] 값이 존재하지 않습니다.		>> %TEMP%\WINLOGIN_BANN.txt
)

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system" | findstr /i "legalnoticetext legalnoticecaption"	> %TEMP%\WINLOGIN_TEMP.txt
set LOGIN1=0
set LOGIN2=0
type %TEMP%\WINLOGIN_TEMP.TXT | findstr /I "legalnoticecaption" | Tools\awk.exe "{print $3}" > %TEMP%\legalnoticecaption.txt
for /F "USEBACKQ DELIMS= tokens=1" %%i in ("%TEMP%\legalnoticecaption.txt") do set LOGIN1=%%i
if "%LOGIN1%" == "0" (
	goto W-75_No
)
type %TEMP%\WINLOGIN_TEMP.TXT | findstr /I "legalnoticetext" | Tools\awk.exe "{print $3}" > %TEMP%\legalnoticetext.txt
for /F "USEBACKQ DELIMS= tokens=1" %%i in ("%TEMP%\legalnoticetext.txt") do set LOGIN2=%%i
if "%LOGIN2%" == "0" (
	goto W-75_No
)

echo ■ 결과 : 양호, 로그인 경고 메시지 제목 및 내용이 설정되어 있음		>> %FILENAME%
goto W-75_end

:W-75_No
echo ■ 결과 : 취약, 로그인 경고 메시지 설정이 미흡함	>> %FILENAME%

:W-75_end
echo.	>> %FILENAME%
echo ■ 상세 현황	>> %FILENAME%
echo.	>> %FILENAME%
type %TEMP%\WINLOGIN_BANN.txt		>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%