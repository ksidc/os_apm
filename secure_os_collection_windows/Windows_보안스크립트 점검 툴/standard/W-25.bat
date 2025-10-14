@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-25. FTP 서비스 구동 점검 >> %FILENAME%
echo. >> %FILENAME%

if %FTP_RUN% EQU 0 (
	echo ■ 결과 : 양호, FTP 서비스가 비활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - FTP 서비스가 구동 중이지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, FTP 서비스가 활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %CONFIG%Net_Start.txt | findstr /i "ftp" >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%