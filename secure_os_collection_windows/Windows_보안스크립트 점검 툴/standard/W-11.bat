@echo off

echo �������������������� W-11. IIS ���͸� ������ ���� >> %FILENAME%
echo. >> %FILENAME%

::����Ʈ�� ����
FOR /f "delims=" %%i IN (%TEMP%\IIS_web_name.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Directory_listing_site.txt
	echo ����Ʈ�� : %%i >> %TEMP%\Directory_listing_site.txt
	%systemroot%\System32\inetsrv\appcmd list config %%i -section:"system.webServer/directoryBrowse" /text:* | findstr /i "[sy enabled Flags" >> %TEMP%\Directory_listing_site.txt
)

type %TEMP%\Directory_listing_site.txt | find /i "true" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ���丮 �˻��� �������� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, ���丮 �˻��� ������ ����Ʈ�� ������ >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [�⺻ ����] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config -section:"system.webServer/directoryBrowse" /text:* | findstr /i "[sy enabled Flags" >> %FILENAME%
echo. >> %FILENAME%
echo [����Ʈ�� ����] >> %FILENAME%
type %TEMP%\Directory_listing_site.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%