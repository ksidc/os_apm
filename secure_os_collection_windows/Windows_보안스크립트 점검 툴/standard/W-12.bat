@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-12. IIS CGI 실행 제한 >> %FILENAME%
echo. >> %FILENAME%

set CGI=0
set EVERY=0

if exist C:\inetpub\scripts (
	set /a CGI+=1
	cacls C:\inetpub\scripts | find /i "everyone" > nul
	if errorlevel 1 (
		echo -----------------------------------------------------------------------  >> %CONFIG%IIS_cgi_cacls.txt
		cacls C:\inetpub\scripts >> %CONFIG%IIS_cgi_cacls.txt
	) else (
		set /a EVERY+=1
		cacls C:\inetpub\scripts >> %TEMP%\CGI_scripts.txt
		echo -----------------------------------------------------------------------  >> %CONFIG%IIS_cgi_cacls.txt
		cacls C:\inetpub\scripts >> %CONFIG%IIS_cgi_cacls.txt
	)
) else (
	echo - C:\inetpub\scripts 디렉토리가 존재하지 않음 >> %TEMP%\CGI_no.txt
)

if exist C:\inetpub\cgi-bin (
	set /a CGI+=1
	cacls C:\inetpub\cgi-bin | find /i "everyone" > nul
	if errorlevel 1 (
		echo -----------------------------------------------------------------------  >> %CONFIG%IIS_cgi_cacls.txt
		cacls C:\inetpub\cgi-bin >> %CONFIG%IIS_cgi_cacls.txt
	) else (
		set /a EVERY+=1
		cacls C:\inetpub\cgi-bin >> %TEMP%\CGI_bin.txt
		echo -----------------------------------------------------------------------  >> %CONFIG%IIS_cgi_cacls.txt
		cacls C:\inetpub\cgi-bin >> %CONFIG%IIS_cgi_cacls.txt
	)
) else (
	echo - C:\inetpub\cgi-bin 디렉토리가 존재하지 않음 >> %TEMP%\CGI_no.txt
)

if %CGI% EQU 0 (
	echo ■ 결과 : 양호, IIS CGI 기본 디렉토리가 존재하지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\CGI_no.txt >> %FILENAME%
) else (
	if %EVERY% EQU 0 (
		echo ■ 결과 : 양호, IIS CGI 기본 디렉토리에 Everyone 사용 권한이 존재하지 않음 >> %FILENAME%
	) else (
		echo ■ 결과 : 취약, IIS CGI 기본 디렉토리에 Everyone 사용 권한이 존재함 >> %FILENAME%
	)
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	if exist %TEMP%\CGI_scripts.txt ( type %TEMP%\CGI_scripts.txt >> %FILENAME% )
	if exist %TEMP%\CGI_bin.txt ( type %TEMP%\CGI_bin.txt >> %FILENAME% )
	echo. >> %FILENAME%
	echo ※ 상세 디렉토리 권한 정보는 %CONFIG%IIS_cgi_cacls.txt 파일을 참고 >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%