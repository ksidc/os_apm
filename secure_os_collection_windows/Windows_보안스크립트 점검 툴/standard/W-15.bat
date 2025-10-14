@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-15. IIS 웹 프로세스 권한 제한 >> %FILENAME%
echo. >> %FILENAME%

%systemroot%\system32\inetsrv\appcmd list apppool /text:* | findstr /i "APPPOOL.NAME IdentityType" >> %TEMP%\App_pool_id.txt

type %TEMP%\App_pool_id.txt | find /i "LocalSystem" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 응용 프로그램 풀 ID가 LocalSystem 으로 설정되지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, ID가 LocalSystem 으로 설정된 응용 프로그램 풀이 존재함 >> %FILENAME%
)
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%

type %TEMP%\App_pool_id.txt >> %FILENAME%
echo. >> %FILENAME%
echo ※ 기본 제공 계정(LocalSystem, NetworkService, LocalService, ApplicationPoolIdentity) 또는 사용자 지정 계정을 사용할 수 있음 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%