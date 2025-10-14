@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-59. IIS 웹 서비스 정보 숨김 >> %FILENAME%
echo. >> %FILENAME%

sc query W3SVC | find /i "state" | find "4"  > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, IIS 서비스가 비활성화되어 있음 >> %FILENAME%
	echo.                              >> %FILENAME%
	echo ■ 상세 현황                              >> %FILENAME%
	echo.                              >> %FILENAME%
	sc query W3SVC | find /i "state" | find "4" >> %FILENAME%
	goto W-59_END
) else (
	echo ■ 결과 : 수동 점검, 에러페이지가 별도로 지정되어 있는지 확인 >> %FILENAME%
	echo. >> %FILENAME%
)

if %IIS_V% LEQ 6 (
	goto IIS_6
) else (
	goto IIS_7
)

:IIS_6
copy C:\WINDOWS\help\iisHelp\common\400.htm %CONFIG%\400.htm  > nul
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo 기본 설정 에러페이지(%CONFIG%400.htm) 참고 >> %FILENAME%
echo. >> %FILENAME%
echo [에러페이지 설정 정보] >> %FILENAME%
type Config\%COMPUTERNAME%_IIS_Config.txt | find /i "HttpErrors=" >> %FILENAME%

:IIS_7
C:\Windows\System32\inetsrv\appcmd.exe list config -section:"system.webServer/httpErrors" /text:* | findstr /i "[error code path: responseMode:" | find /V /I "subStatusCode"	> %TEMP%\error_info.txt
copy C:\inetpub\custerr\ko-KR\401.htm %CONFIG%401.htm  > nul
echo ■ 상세 현황                              >> %FILENAME%
echo.                              >> %FILENAME%
echo 기본 설정 에러페이지(%CONFIG%401.htm) 참고          >> %FILENAME%
echo.                              >> %FILENAME%
echo [에러페이지 설정 정보]                              >> %FILENAME%
type %TEMP%\error_info.txt                              >> %FILENAME%

:W-59_END
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%