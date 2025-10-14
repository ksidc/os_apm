@echo off

echo �������������������� W-12. IIS CGI ���� ���� >> %FILENAME%
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
	echo - C:\inetpub\scripts ���丮�� �������� ���� >> %TEMP%\CGI_no.txt
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
	echo - C:\inetpub\cgi-bin ���丮�� �������� ���� >> %TEMP%\CGI_no.txt
)

if %CGI% EQU 0 (
	echo �� ��� : ��ȣ, IIS CGI �⺻ ���丮�� �������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\CGI_no.txt >> %FILENAME%
) else (
	if %EVERY% EQU 0 (
		echo �� ��� : ��ȣ, IIS CGI �⺻ ���丮�� Everyone ��� ������ �������� ���� >> %FILENAME%
	) else (
		echo �� ��� : ���, IIS CGI �⺻ ���丮�� Everyone ��� ������ ������ >> %FILENAME%
	)
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	if exist %TEMP%\CGI_scripts.txt ( type %TEMP%\CGI_scripts.txt >> %FILENAME% )
	if exist %TEMP%\CGI_bin.txt ( type %TEMP%\CGI_bin.txt >> %FILENAME% )
	echo. >> %FILENAME%
	echo �� �� ���丮 ���� ������ %CONFIG%IIS_cgi_cacls.txt ������ ���� >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%