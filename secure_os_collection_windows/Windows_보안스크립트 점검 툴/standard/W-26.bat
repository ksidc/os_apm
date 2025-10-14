@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-26. FTP 디렉토리 접근권한 설정 >> %FILENAME%
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
		type %TEMP%\FTP_path_acl.txt | find /i "Everyone" > nul
		if errorlevel 1 (
			echo ■ 결과 : 양호, FTP 홈 디렉토리에 Everyone 사용 권한이 설정되지 않음  >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP 사이트] >> %FILENAME%
			type %CONFIG%FTP_SiteList.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP 사이트 홈디렉토리] >> %FILENAME%
			type %TEMP%\FTP_homedir.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP 사이트별 홈디렉토리 접근권한] >> %FILENAME%
			type %TEMP%\FTP_path_acl.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo - Everyone 사용 권한이 설정되지 않음 >> %FILENAME%
		) else (
			echo ■ 결과 : 취약, FTP 홈 디렉토리에 Everyone 사용 권한이 설정되어 있음  >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP 사이트] >> %FILENAME%
			type %CONFIG%FTP_SiteList.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP 사이트 홈디렉토리] >> %FILENAME%
			type %TEMP%\FTP_homedir.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP 사이트별 홈디렉토리 접근권한] >> %FILENAME%
			type %TEMP%\FTP_path_acl.txt	>> %FILENAME%
		)
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%