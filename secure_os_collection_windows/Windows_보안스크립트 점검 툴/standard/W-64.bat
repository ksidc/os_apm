@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-64. HTTP/FTP/SMTP 배너 차단 >> %FILENAME%
echo. >> %FILENAME%

:: HTTP
set R_HTTP=0
set B_HTTP=0
echo [HTTP] > %TEMP%\Banner_Check.txt

sc query W3SVC | findstr /i "state" | findstr "4" > nul
if errorlevel 1 (
	echo - HTTP 서비스가 비활성화 되어 있음 >> %TEMP%\Banner_Check.txt
) else (
	set /a R_HTTP+=1
	reg query "HKLM\SYSTEM\CurrentControlSet\Services\HTTP\parameters" > %TEMP%\Banner_http.txt 2>&1
	type %TEMP%\Banner_http.txt | findstr /i "DisableServerHeader" > nul
	if errorlevel 1 (
		set /a B_HTTP+=1
		echo - DisableServerHeader 값이 정의되어 있지 않음 >> %TEMP%\Banner_Check.txt
		echo * 단, URLScan 또는 URLRewrite 등의 기능을 이용하여 기본 배너를 차단하고 있을 수 있음 >> %TEMP%\Banner_Check.txt
	) else (
		type %TEMP%\Banner_http.txt | findstr /i "DisableServerHeader" | findstr /i "0x1" > nul
		if errorlevel 1 (
			set /a B_HTTP+=1
			echo - HTTP 배너 차단이 설정되어 있지 않음 >> %TEMP%\Banner_Check.txt
			echo * 단, URLScan 또는 URLRewrite 등의 기능을 이용하여 기본 배너를 차단하고 있을 수 있음 >> %TEMP%\Banner_Check.txt
		) else (
			echo - HTTP 배너 차단이 설정되어 있음 >> %TEMP%\Banner_Check.txt
		)
		echo. >> %TEMP%\Banner_Check.txt
		type %TEMP%\Banner_http.txt | findstr /i "DisableServerHeader" >> %TEMP%\Banner_Check.txt
	)
)
echo. >> %TEMP%\Banner_Check.txt

:: FTP
set R_FTP=0
set B_FTP=0
echo [FTP] >> %TEMP%\Banner_Check.txt

type Config\%COMPUTERNAME%_Net_Start.txt | findstr /i "FTP" > nul
if errorlevel 1 (
	echo - FTP 서비스가 비활성화 되어 있음 >> %TEMP%\Banner_Check.txt
) else (
	set /a R_FTP+=1
	echo quit > %TEMP%\FTP_quit.txt
	ftp -A -s:%TEMP%\FTP_quit.txt 127.0.0.1  >> %TEMP%\FTP_try.txt 2>&1
	type %TEMP%\FTP_try.txt | findstr /i /c:"Microsoft FTP Service" > nul
	if errorlevel 1 (
		type %TEMP%\FTP_try.txt | findstr /i "FileZilla" > nul
		if errorlevel 1 (
			echo - FTP 기본 배너가 차단되어 있음 >> %TEMP%\Banner_Check.txt
		) else (
			set /a B_FTP+=1
			echo - FileZilla 서비스를 사용하고 있음 >> %TEMP%\Banner_Check.txt
		)
	) else (
		set /a B_FTP+=1
		echo - FTP 기본 배너가 설정되어 있음 >> %TEMP%\Banner_Check.txt
	)
	echo. >> %TEMP%\Banner_Check.txt
	type Config\%COMPUTERNAME%_Net_Start.txt | findstr /i "FTP" >> %TEMP%\Banner_Check.txt
	echo. >> %TEMP%\Banner_Check.txt
	type %TEMP%\FTP_try.txt >> %TEMP%\Banner_Check.txt
)
echo. >> %TEMP%\Banner_Check.txt

:: SMTP
set R_SMTP=0
echo [SMTP] >> %TEMP%\Banner_Check.txt

type Config\%COMPUTERNAME%_Net_Start.txt | findstr /i "SMTP" > nul
if errorlevel 1 (
	echo - SMTP 서비스가 비활성화 되어 있음 >> %TEMP%\Banner_Check.txt
) else (
	set /a R_SMTP+=1
	echo - SMTP 서비스가 활성화 되어 있음 >> %TEMP%\Banner_Check.txt
	echo. >> %TEMP%\Banner_Check.txt
	type Config\%COMPUTERNAME%_Net_Start.txt | findstr /i "SMTP" >> %TEMP%\Banner_Check.txt
)

set /a R_SUM=%R_HTTP%+%R_FTP%+%R_SMTP%
set /a B_SUM=%B_HTTP%+%B_FTP%
if "%R_SUM%" == "0" (
	echo ■ 결과 : 양호, HTTP/FTP/SMTP 서비스가 모두 비활성화 되어 있음 >> %FILENAME%
) else (
	if "%B_SUM%" == "0" (
		echo ■ 결과 : 양호, HTTP/FTP/SMTP 서비스가 비활성화 상태이거나 기본 배너를 차단하고 있음 >> %FILENAME%
	) else (
		echo ■ 결과 : 취약, HTTP/FTP/SMTP 서비스의 전체 또는 일부가 기본 배너를 설정하고 있음 >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Banner_Check.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%