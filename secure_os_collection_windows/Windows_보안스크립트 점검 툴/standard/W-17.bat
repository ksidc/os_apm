@echo off

echo �������������������� W-17. IIS ���� ���ε� �� �ٿ�ε� ���� >> %FILENAME%
echo. >> %FILENAME%
echo �� ��� : ��������, ������ �뷮 �� ���� ���ε�/�ٿ�ε� �뷮�� �ּ� ������ �����ϰ� �ִ��� ���� >> %FILENAME%
echo. >> %FILENAME%

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%

echo [applicationHost.config ����] >> %FILENAME%
type %systemroot%\System32\inetsrv\Config\applicationHost.config | findstr /i "maxAllowedContentLength maxRequestEntityAllowed bufferingLimit" > nul
if errorlevel 1 (
	echo - ���� �������� ���� >> %FILENAME%
) else (
	type %systemroot%\System32\inetsrv\Config\applicationHost.config | findstr /i "maxAllowedContentLength maxRequestEntityAllowed bufferingLimit" >> %FILENAME%
)

echo. >> %FILENAME%
echo [����Ʈ�� ����] >> %FILENAME%
FOR /f "delims=" %%a IN (%TEMP%\IIS_web_name.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\File_up_down.txt
	echo ����Ʈ�� : %%a >> %TEMP%\File_up_down.txt
	%systemroot%\System32\inetsrv\appcmd list config %%a | findstr /i "maxAllowedContentLength maxRequestEntityAllowed bufferingLimit" > nul
	if errorlevel 1 (
		echo - ���� �������� ���� >> %TEMP%\File_up_down.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%a | findstr /i "maxAllowedContentLength maxRequestEntityAllowed bufferingLimit" >> %TEMP%\File_up_down.txt
	)
)
type %TEMP%\File_up_down.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� ���� �������� �ʴ� ��� �⺻ ������ ����Ǿ� �ִ� ������, �⺻ �������� �Ʒ� ������ ���� >> %FILENAME%
echo     maxAllowedContentLength(������ �뷮) : Default 30MB >> %FILENAME%
echo     maxRequestEntityAllowed(���� ���ε� �뷮) : Default 200000 byte >> %FILENAME%
echo     bufferingLimit(���� �ٿ�ε� �뷮) : Default 4MB(4194304 byte) >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%