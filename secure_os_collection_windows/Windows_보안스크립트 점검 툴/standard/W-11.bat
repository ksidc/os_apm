@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-11. IIS 디렉터리 리스팅 제거 >> %FILENAME%
echo. >> %FILENAME%

::사이트별 설정
FOR /f "delims=" %%i IN (%TEMP%\IIS_web_name.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Directory_listing_site.txt
	echo 사이트명 : %%i >> %TEMP%\Directory_listing_site.txt
	%systemroot%\System32\inetsrv\appcmd list config %%i -section:"system.webServer/directoryBrowse" /text:* | findstr /i "[sy enabled Flags" >> %TEMP%\Directory_listing_site.txt
)

type %TEMP%\Directory_listing_site.txt | find /i "true" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 디렉토리 검색이 설정되지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, 디렉토리 검색이 설정된 사이트가 존재함 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [기본 설정] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config -section:"system.webServer/directoryBrowse" /text:* | findstr /i "[sy enabled Flags" >> %FILENAME%
echo. >> %FILENAME%
echo [사이트별 설정] >> %FILENAME%
type %TEMP%\Directory_listing_site.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%