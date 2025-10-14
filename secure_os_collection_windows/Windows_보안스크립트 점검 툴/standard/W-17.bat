@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-17. IIS 파일 업로드 및 다운로드 제한 >> %FILENAME%
echo. >> %FILENAME%
echo ■ 결과 : 수동점검, 콘텐츠 용량 및 파일 업로드/다운로드 용량을 최소 범위로 제한하고 있는지 점검 >> %FILENAME%
echo. >> %FILENAME%

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%

echo [applicationHost.config 파일] >> %FILENAME%
type %systemroot%\System32\inetsrv\Config\applicationHost.config | findstr /i "maxAllowedContentLength maxRequestEntityAllowed bufferingLimit" > nul
if errorlevel 1 (
	echo - 값이 존재하지 않음 >> %FILENAME%
) else (
	type %systemroot%\System32\inetsrv\Config\applicationHost.config | findstr /i "maxAllowedContentLength maxRequestEntityAllowed bufferingLimit" >> %FILENAME%
)

echo. >> %FILENAME%
echo [사이트별 설정] >> %FILENAME%
FOR /f "delims=" %%a IN (%TEMP%\IIS_web_name.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\File_up_down.txt
	echo 사이트명 : %%a >> %TEMP%\File_up_down.txt
	%systemroot%\System32\inetsrv\appcmd list config %%a | findstr /i "maxAllowedContentLength maxRequestEntityAllowed bufferingLimit" > nul
	if errorlevel 1 (
		echo - 값이 존재하지 않음 >> %TEMP%\File_up_down.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%a | findstr /i "maxAllowedContentLength maxRequestEntityAllowed bufferingLimit" >> %TEMP%\File_up_down.txt
	)
)
type %TEMP%\File_up_down.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 값이 존재하지 않는 경우 기본 설정이 적용되어 있는 것으로, 기본 설정값은 아래 내용을 참고 >> %FILENAME%
echo     maxAllowedContentLength(콘텐츠 용량) : Default 30MB >> %FILENAME%
echo     maxRequestEntityAllowed(파일 업로드 용량) : Default 200000 byte >> %FILENAME%
echo     bufferingLimit(파일 다운로드 용량) : Default 4MB(4194304 byte) >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%