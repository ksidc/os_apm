@echo off

echo �������������������� W-59. IIS �� ���� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

sc query W3SVC | find /i "state" | find "4"  > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, IIS ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo.                              >> %FILENAME%
	echo �� �� ��Ȳ                              >> %FILENAME%
	echo.                              >> %FILENAME%
	sc query W3SVC | find /i "state" | find "4" >> %FILENAME%
	goto W-59_END
) else (
	echo �� ��� : ���� ����, ������������ ������ �����Ǿ� �ִ��� Ȯ�� >> %FILENAME%
	echo. >> %FILENAME%
)

if %IIS_V% LEQ 6 (
	goto IIS_6
) else (
	goto IIS_7
)

:IIS_6
copy C:\WINDOWS\help\iisHelp\common\400.htm %CONFIG%\400.htm  > nul
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo �⺻ ���� ����������(%CONFIG%400.htm) ���� >> %FILENAME%
echo. >> %FILENAME%
echo [���������� ���� ����] >> %FILENAME%
type Config\%COMPUTERNAME%_IIS_Config.txt | find /i "HttpErrors=" >> %FILENAME%

:IIS_7
C:\Windows\System32\inetsrv\appcmd.exe list config -section:"system.webServer/httpErrors" /text:* | findstr /i "[error code path: responseMode:" | find /V /I "subStatusCode"	> %TEMP%\error_info.txt
copy C:\inetpub\custerr\ko-KR\401.htm %CONFIG%401.htm  > nul
echo �� �� ��Ȳ                              >> %FILENAME%
echo.                              >> %FILENAME%
echo �⺻ ���� ����������(%CONFIG%401.htm) ����          >> %FILENAME%
echo.                              >> %FILENAME%
echo [���������� ���� ����]                              >> %FILENAME%
type %TEMP%\error_info.txt                              >> %FILENAME%

:W-59_END
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%