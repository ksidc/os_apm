@echo off

echo �������������������� W-75. ��� �޽��� ����	>> %FILENAME%
echo.	>> %FILENAME%
echo [�α��� ��� ����]		> %TEMP%\WINLOGIN_BANN.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "legalnoticecaption" | Tools\awk.exe -F\ "{print $8}"	>> %TEMP%\WINLOGIN_BANN.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "legalnoticecaption" > nul
if errorlevel 1 (
	echo legalnoticecaption[��� ����] ���� �������� �ʽ��ϴ�.	>> %TEMP%\WINLOGIN_BANN.txt
)
echo .					>> %TEMP%\WINLOGIN_BANN.txt
echo [�α��� ��� ����]		>> %TEMP%\WINLOGIN_BANN.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "legalnoticetext" | Tools\awk.exe -F\ "{print $8}"		>> %TEMP%\WINLOGIN_BANN.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "legalnoticetext" > nul
if errorlevel 1 (
	echo legalnoticetext[��� ����] ���� �������� �ʽ��ϴ�.		>> %TEMP%\WINLOGIN_BANN.txt
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

echo �� ��� : ��ȣ, �α��� ��� �޽��� ���� �� ������ �����Ǿ� ����		>> %FILENAME%
goto W-75_end

:W-75_No
echo �� ��� : ���, �α��� ��� �޽��� ������ ������	>> %FILENAME%

:W-75_end
echo.	>> %FILENAME%
echo �� �� ��Ȳ	>> %FILENAME%
echo.	>> %FILENAME%
type %TEMP%\WINLOGIN_BANN.txt		>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%