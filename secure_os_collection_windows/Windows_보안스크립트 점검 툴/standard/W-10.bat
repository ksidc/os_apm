@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-10. IIS 서비스 구동 점검 >> %FILENAME%
echo. >> %FILENAME%

if %IIS_RUN% EQU 0 (
	echo ■ 결과 : 양호, IIS 서비스가 비활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - IIS 서비스가 구동 중이지 않음 >> %FILENAME%
) 
if %IIS_RUN% EQU 1 (
	echo ■ 결과 : 수동점검, IIS 서비스를 구동 중이므로 필요에 의하여 사용 중인지 확인 필요 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %CONFIG%Net_Start.txt | find /i "World Wide Web Publishing" >> %FILENAME%
	echo. >> %FILENAME%
	sc query W3SVC | findstr /i "W3SVC STATE" >> %FILENAME%
	echo. >> %FILENAME%
	echo [IIS 버전] >> %FILENAME%
	reg query "HKLM\SOFTWARE\Microsoft\InetStp" | findstr /i "SetupString" >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%