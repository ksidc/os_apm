@echo off

echo �������������������� W-65. Telnet ���� ���� >> %FILENAME%
echo.	>> %FILENAME%
net start | findstr /I "Telnet"	> nul

if errorlevel 1 (
	echo �� ��� : ��ȣ, Telnet ���񽺰� ��Ȱ��ȭ�Ǿ� ����		 >> %FILENAME%
	echo "Telnet ���񽺰� ��Ȱ��ȭ �Ǿ� ����"	>> %TEMP%\Telnet_Auth_Met.txt
) else (
	tlntadmn config	>> %TEMP%\Telnet_Auth_Met.txt
	type %TEMP%\Telnet_Auth_Met.txt | findstr /I "Authentication" 	> nul
	type %TEMP%\Telnet_Auth_Met.txt | findstr /I "password" 		> nul
	if errorlevel 1 (
		echo �� ��� : ��ȣ		 >> %FILENAME%
	) else (
		echo �� ��� : ���		 >> %FILENAME%
	)
)
echo.	>> %FILENAME%
echo �� �� ��Ȳ		 >> %FILENAME%
echo.	>> %FILENAME%
type %TEMP%\Telnet_Auth_Met.txt | findstr /I "Authentication" 	 >> %FILENAME%	
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%