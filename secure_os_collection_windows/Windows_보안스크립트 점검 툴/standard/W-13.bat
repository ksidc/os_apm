@echo off

echo �������������������� W-13. IIS ���� ���丮 ���� ���� >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%i IN (%TEMP%\IIS_web_name.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Directory_parent_path.txt
	echo ����Ʈ�� : %%i >> %TEMP%\Directory_parent_path.txt
	%systemroot%\System32\inetsrv\appcmd list config %%i -section:"system.webServer/asp" /text:* | findstr /i "[sy enableParentPaths" >> %TEMP%\Directory_parent_path.txt
)

type %TEMP%\Directory_parent_path.txt | find /i "true" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, �θ�/���� ��� ����� �������� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, �θ�/���� ��� ����� ������ ����Ʈ�� ������ >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [�⺻ ����] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config -section:"system.webServer/asp" /text:* | findstr /i "[sy enableParentPaths" >> %FILENAME%
echo. >> %FILENAME%
echo [����Ʈ�� ����] >> %FILENAME%
type %TEMP%\Directory_parent_path.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%