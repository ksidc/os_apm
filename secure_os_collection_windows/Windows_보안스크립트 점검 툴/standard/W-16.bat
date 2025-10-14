@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-16. IIS 링크 사용 금지 >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%j IN (%TEMP%\IIS_root_path.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Link_files.txt
	echo 홈 디렉토리 경로 : %%j >> %TEMP%\Link_files.txt
	dir /s /b %%j | find /i ".lnk" > nul
	if errorlevel 1 (
		echo - 링크 파일이 존재하지 않음 >> %TEMP%\Link_files.txt
	) else (
		dir /s /b %%j | find /i ".lnk" >> %TEMP%\Link_files.txt
	)
	echo. >> %TEMP%\Link_files.txt
)

type %TEMP%\Link_files.txt | find /i ".lnk" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 웹 사이트 홈 디렉토리에 링크 파일이 존재하지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, 링크 파일이 존재하는 웹 사이트 홈 디렉토리가 확인됨 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [사이트 목록] >> %FILENAME%
type %CONFIG%IIS_WebList.txt >> %FILENAME%
echo. >> %FILENAME%
echo [홈 디렉토리 정보] >> %FILENAME%
FOR /f "delims=" %%k IN (%TEMP%\IIS_web_name.txt) DO (
	%systemroot%\System32\inetsrv\appcmd list site %%k /config | findstr /i "name protocol physicalpath" >> %FILENAME%
)
echo. >> %FILENAME%
echo [사이트별 불필요 파일 확인] >> %FILENAME%
type %TEMP%\Link_files.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%