@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-13. IIS 상위 디렉토리 접근 금지 >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%i IN (%TEMP%\IIS_web_name.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Directory_parent_path.txt
	echo 사이트명 : %%i >> %TEMP%\Directory_parent_path.txt
	%systemroot%\System32\inetsrv\appcmd list config %%i -section:"system.webServer/asp" /text:* | findstr /i "[sy enableParentPaths" >> %TEMP%\Directory_parent_path.txt
)

type %TEMP%\Directory_parent_path.txt | find /i "true" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 부모/상위 경로 사용이 설정되지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, 부모/상위 경로 사용이 설정된 사이트가 존재함 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [기본 설정] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config -section:"system.webServer/asp" /text:* | findstr /i "[sy enableParentPaths" >> %FILENAME%
echo. >> %FILENAME%
echo [사이트별 설정] >> %FILENAME%
type %TEMP%\Directory_parent_path.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%