@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-27. Anonymous FTP 금지 >> %FILENAME%
echo. >> %FILENAME%

if %FTP_RUN% EQU 0 (
	echo ■ 결과 : 양호, FTP 서비스가 비활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - FTP 서비스가 구동 중이지 않음 >> %FILENAME%
) else (
	if %FTP_RUN% EQU 2 (
		echo ■ 결과 : 수동점검, 윈도우 기본 FTP 외 타 FTP 서비스 구동중으로 별도 점검 필요 >> %FILENAME%
		echo. >> %FILENAME%
		echo ■ 상세 현황 >> %FILENAME%
		echo. >> %FILENAME%
		type %CONFIG%Net_Start.txt | find /i "ftp" >> %FILENAME%
	)
	if %FTP_RUN% EQU 1 (
		FOR /f "delims=" %%a IN (%TEMP%\FTP_site_name.txt) DO (
			echo -----------------------------------------------------------------------  >> %TEMP%\FTP_anonymous.txt
			echo 사이트명 : %%a >> %TEMP%\FTP_anonymous.txt
			%systemroot%\System32\inetsrv\appcmd list site %%a /config | find /i "anonymousAuthentication enabled" >> %TEMP%\FTP_anonymous.txt
		)
		type %TEMP%\FTP_anonymous.txt | find /i "true" > nul
		if errorlevel 1 (
			echo ■ 결과 : 양호, 익명 인증이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
		) else (
			echo ■ 결과 : 취약, 익명 인증이 '사용'으로 설정된 FTP 사이트가 존재함 >> %FILENAME%
		)
		echo. >> %FILENAME%
		echo ■ 상세 현황 >> %FILENAME%
		echo. >> %FILENAME%
		type %TEMP%\FTP_anonymous.txt >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%