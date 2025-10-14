@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-09. 불필요한 서비스 제거 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Net_Start.txt | findstr /i "Alerter ClipBook Messenger" >> %TEMP%\Netstart_service.txt
type %CONFIG%Net_Start.txt | find /i "Simple TCP/IP Services" >> %TEMP%\Netstart_service.txt
:: type %CONFIG%Net_Start.txt | findstr /i "DHCP DNS" | find /i "Client" >> %TEMP%\Netstart_service.txt
:: type %CONFIG%Net_Start.txt | findstr /i "Cryptographic Print" >> %TEMP%\Netstart_service.txt
type %CONFIG%Net_Start.txt | find /i "Distributed Link Tracking" >> %TEMP%\Netstart_service.txt

type %TEMP%\Netstart_service.txt | findstr /i "Alerter ClipBook Messenger Simple DHCP DNS Cryptographic Distributed" > nul
if errorlevel 1 (
	set service=0
	echo ■ 결과 : 양호, 불필요한 서비스가 존재하지 않음 >> %FILENAME%
) else (
	set service=1
	echo ■ 결과 : 취약, 불필요한 서비스가 구동되고 있음 >> %FILENAME%
)
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
if %service% EQU 0 (
	echo - 불필요한 서비스가 존재하지 않음 >> %FILENAME%
) else (
	type %TEMP%\Netstart_service.txt >> %FILENAME%
)

echo. >> %FILENAME%
echo ※ 구동중인 전체 서비스 목록은 %CONFIG%Net_Start.txt 파일 참고 >> %FILENAME%


echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%