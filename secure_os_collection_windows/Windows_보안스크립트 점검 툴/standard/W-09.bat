@echo off

echo �������������������� W-09. ���ʿ��� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Net_Start.txt | findstr /i "Alerter ClipBook Messenger" >> %TEMP%\Netstart_service.txt
type %CONFIG%Net_Start.txt | find /i "Simple TCP/IP Services" >> %TEMP%\Netstart_service.txt
:: type %CONFIG%Net_Start.txt | findstr /i "DHCP DNS" | find /i "Client" >> %TEMP%\Netstart_service.txt
:: type %CONFIG%Net_Start.txt | findstr /i "Cryptographic Print" >> %TEMP%\Netstart_service.txt
type %CONFIG%Net_Start.txt | find /i "Distributed Link Tracking" >> %TEMP%\Netstart_service.txt

type %TEMP%\Netstart_service.txt | findstr /i "Alerter ClipBook Messenger Simple DHCP DNS Cryptographic Distributed" > nul
if errorlevel 1 (
	set service=0
	echo �� ��� : ��ȣ, ���ʿ��� ���񽺰� �������� ���� >> %FILENAME%
) else (
	set service=1
	echo �� ��� : ���, ���ʿ��� ���񽺰� �����ǰ� ���� >> %FILENAME%
)
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
if %service% EQU 0 (
	echo - ���ʿ��� ���񽺰� �������� ���� >> %FILENAME%
) else (
	type %TEMP%\Netstart_service.txt >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �������� ��ü ���� ����� %CONFIG%Net_Start.txt ���� ���� >> %FILENAME%


echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%