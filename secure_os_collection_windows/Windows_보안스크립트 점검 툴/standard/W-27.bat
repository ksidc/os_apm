@echo off

echo �������������������� W-27. Anonymous FTP ���� >> %FILENAME%
echo. >> %FILENAME%

if %FTP_RUN% EQU 0 (
	echo �� ��� : ��ȣ, FTP ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - FTP ���񽺰� ���� ������ ���� >> %FILENAME%
) else (
	if %FTP_RUN% EQU 2 (
		echo �� ��� : ��������, ������ �⺻ FTP �� Ÿ FTP ���� ���������� ���� ���� �ʿ� >> %FILENAME%
		echo. >> %FILENAME%
		echo �� �� ��Ȳ >> %FILENAME%
		echo. >> %FILENAME%
		type %CONFIG%Net_Start.txt | find /i "ftp" >> %FILENAME%
	)
	if %FTP_RUN% EQU 1 (
		FOR /f "delims=" %%a IN (%TEMP%\FTP_site_name.txt) DO (
			echo -----------------------------------------------------------------------  >> %TEMP%\FTP_anonymous.txt
			echo ����Ʈ�� : %%a >> %TEMP%\FTP_anonymous.txt
			%systemroot%\System32\inetsrv\appcmd list site %%a /config | find /i "anonymousAuthentication enabled" >> %TEMP%\FTP_anonymous.txt
		)
		type %TEMP%\FTP_anonymous.txt | find /i "true" > nul
		if errorlevel 1 (
			echo �� ��� : ��ȣ, �͸� ������ '��� �� ��'���� �����Ǿ� ���� >> %FILENAME%
		) else (
			echo �� ��� : ���, �͸� ������ '���'���� ������ FTP ����Ʈ�� ������ >> %FILENAME%
		)
		echo. >> %FILENAME%
		echo �� �� ��Ȳ >> %FILENAME%
		echo. >> %FILENAME%
		type %TEMP%\FTP_anonymous.txt >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%