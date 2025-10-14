@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-18. IIS DB 연결 취약점 점검 >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%k IN (%TEMP%\IIS_web_name.txt) DO (
	::echo -----------------------------------------------------------------------  >> %TEMP%\File_asa.txt
	echo 사이트명 : %%k >> %TEMP%\File_asa.txt
	%systemroot%\System32\inetsrv\appcmd list config %%k | find /i "add fileExtension" | find /i ".asa" > nul
	if errorlevel 1 (
		echo - .asa .asax 확장자 필터링 설정 내역이 존재하지 않음 >> %TEMP%\File_asa.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%k | find /i "add fileExtension" | find /i ".asa" >> %TEMP%\File_asa.txt
	)
)

FOR /f "delims=" %%i IN (%TEMP%\IIS_web_name.txt) DO (
	::echo -----------------------------------------------------------------------  >> %TEMP%\W-18_Mapping_handler.txt
	echo 사이트명 : %%i >> %TEMP%\W-18_Mapping_handler.txt
	%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.asa \.asax" > nul
	if errorlevel 1 (
		echo - 취약한 매핑이 존재하지 않음 >> %TEMP%\W-18_Mapping_handler.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.asa \.asax" >> %TEMP%\W-18_Mapping_handler.txt
	)
)

type %TEMP%\File_asa.txt | find /i "true" > nul
if errorlevel 1 (
	type %TEMP%\W-18_Mapping_handler.txt | findstr /i "\.asa \.asax" > nul
	if errorlevel 1 (
		echo ■ 결과 : 양호, 요청 필터링에 .asa .asax 확장자를 허용하지 않으며, 처리기 매핑에 .asa .asax를 등록하지 않음	>> %FILENAME%
	) else (
		echo ■ 결과 : 취약, 요청 필터링에 .asa .asax 확장자를 허용하지 않으나, 처리기 매핑에 .asa .asax를 등록하고 있음	>> %FILENAME%
	)
) else (	
	type %TEMP%\W-18_Mapping_handler.txt | findstr /i "\.asa \.asax" > nul
	if errorlevel 1 (
		echo ■ 결과 : 취약, 요청 필터링에 .asa .asax 확장자를 허용하고 있으며, 처리기 매핑에 .asa .asax를 등록하지 않음	>> %FILENAME%
	) else (
		echo ■ 결과 : 취약, 요청 필터링에 .asa .asax 확장자를 허용하고 있으며, 처리기 매핑에 .asa .asax를 등록하고 있음	>> %FILENAME%
	)
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo ^<요청 필터링^>	>> %FILENAME%
echo [기본 설정] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config | find /i "add fileExtension" | find /i ".asa" > nul
if errorlevel 1 (
	echo - .asa .asax 확장자 필터링 설정 내역이 존재하지 않음 >> %FILENAME%
) else (
	%systemroot%\System32\inetsrv\appcmd list config | find /i "add fileExtension" | find /i ".asa" >> %FILENAME%
)
echo. >> %FILENAME%

echo [사이트별 설정] >> %FILENAME%
type %TEMP%\File_asa.txt >> %FILENAME%
echo. >> %FILENAME%

echo -----------------------------------------------------------------------	>> %FILENAME%
echo ^<처리기 매핑^>	>> %FILENAME%
echo [기본 설정] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config | find /i "scriptprocessor" | findstr /i "\.asa \.asax" > nul
if errorlevel 1 (
	echo - 취약한 매핑이 존재하지 않음 >> %FILENAME%
) else (
	%systemroot%\System32\inetsrv\appcmd list config | find /i "scriptprocessor" | findstr /i "\.asa \.asax" >> %FILENAME%
)
echo. >> %FILENAME%

echo [사이트별 설정] >> %FILENAME%
type %TEMP%\W-18_Mapping_handler.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%