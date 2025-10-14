@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-24. NetBIOS 바인딩 서비스 구동 점검 >> %FILENAME%
echo. >> %FILENAME%

reg query "HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces" /s | findstr . >> %CONFIG%NetBT.txt
type %CONFIG%NetBT.txt | find /i "NetbiosOptions" | findstr "0x0 0x1" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, NetbiosOptions가 'NetBIOS over TCP/IP 사용 안 함'으로 설정되어 있음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, NetbiosOptions가 'NetBIOS over TCP/IP 사용' 또는 기본값으로 설정되어 있음 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%NetBT.txt | find /i /v "ServerList" >> %FILENAME%

echo. >> %FILENAME%
echo ※ NetbiosOptions - 0x2: NetBIOS 사용 안 함, 0x1: NetBIOS 사용, 0x0: 기본값 >> %FILENAME%
echo    TCP/IP 네트워크 설정값은 %CONFIG%IPconfig.txt 파일 참고 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%