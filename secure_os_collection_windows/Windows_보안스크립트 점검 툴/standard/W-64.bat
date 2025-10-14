@echo off

echo �������������������� W-64. HTTP/FTP/SMTP ��� ���� >> %FILENAME%
echo. >> %FILENAME%

:: HTTP
set R_HTTP=0
set B_HTTP=0
echo [HTTP] > %TEMP%\Banner_Check.txt

sc query W3SVC | findstr /i "state" | findstr "4" > nul
if errorlevel 1 (
	echo - HTTP ���񽺰� ��Ȱ��ȭ �Ǿ� ���� >> %TEMP%\Banner_Check.txt
) else (
	set /a R_HTTP+=1
	reg query "HKLM\SYSTEM\CurrentControlSet\Services\HTTP\parameters" > %TEMP%\Banner_http.txt 2>&1
	type %TEMP%\Banner_http.txt | findstr /i "DisableServerHeader" > nul
	if errorlevel 1 (
		set /a B_HTTP+=1
		echo - DisableServerHeader ���� ���ǵǾ� ���� ���� >> %TEMP%\Banner_Check.txt
		echo * ��, URLScan �Ǵ� URLRewrite ���� ����� �̿��Ͽ� �⺻ ��ʸ� �����ϰ� ���� �� ���� >> %TEMP%\Banner_Check.txt
	) else (
		type %TEMP%\Banner_http.txt | findstr /i "DisableServerHeader" | findstr /i "0x1" > nul
		if errorlevel 1 (
			set /a B_HTTP+=1
			echo - HTTP ��� ������ �����Ǿ� ���� ���� >> %TEMP%\Banner_Check.txt
			echo * ��, URLScan �Ǵ� URLRewrite ���� ����� �̿��Ͽ� �⺻ ��ʸ� �����ϰ� ���� �� ���� >> %TEMP%\Banner_Check.txt
		) else (
			echo - HTTP ��� ������ �����Ǿ� ���� >> %TEMP%\Banner_Check.txt
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
	echo - FTP ���񽺰� ��Ȱ��ȭ �Ǿ� ���� >> %TEMP%\Banner_Check.txt
) else (
	set /a R_FTP+=1
	echo quit > %TEMP%\FTP_quit.txt
	ftp -A -s:%TEMP%\FTP_quit.txt 127.0.0.1  >> %TEMP%\FTP_try.txt 2>&1
	type %TEMP%\FTP_try.txt | findstr /i /c:"Microsoft FTP Service" > nul
	if errorlevel 1 (
		type %TEMP%\FTP_try.txt | findstr /i "FileZilla" > nul
		if errorlevel 1 (
			echo - FTP �⺻ ��ʰ� ���ܵǾ� ���� >> %TEMP%\Banner_Check.txt
		) else (
			set /a B_FTP+=1
			echo - FileZilla ���񽺸� ����ϰ� ���� >> %TEMP%\Banner_Check.txt
		)
	) else (
		set /a B_FTP+=1
		echo - FTP �⺻ ��ʰ� �����Ǿ� ���� >> %TEMP%\Banner_Check.txt
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
	echo - SMTP ���񽺰� ��Ȱ��ȭ �Ǿ� ���� >> %TEMP%\Banner_Check.txt
) else (
	set /a R_SMTP+=1
	echo - SMTP ���񽺰� Ȱ��ȭ �Ǿ� ���� >> %TEMP%\Banner_Check.txt
	echo. >> %TEMP%\Banner_Check.txt
	type Config\%COMPUTERNAME%_Net_Start.txt | findstr /i "SMTP" >> %TEMP%\Banner_Check.txt
)

set /a R_SUM=%R_HTTP%+%R_FTP%+%R_SMTP%
set /a B_SUM=%B_HTTP%+%B_FTP%
if "%R_SUM%" == "0" (
	echo �� ��� : ��ȣ, HTTP/FTP/SMTP ���񽺰� ��� ��Ȱ��ȭ �Ǿ� ���� >> %FILENAME%
) else (
	if "%B_SUM%" == "0" (
		echo �� ��� : ��ȣ, HTTP/FTP/SMTP ���񽺰� ��Ȱ��ȭ �����̰ų� �⺻ ��ʸ� �����ϰ� ���� >> %FILENAME%
	) else (
		echo �� ��� : ���, HTTP/FTP/SMTP ������ ��ü �Ǵ� �Ϻΰ� �⺻ ��ʸ� �����ϰ� ���� >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Banner_Check.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%