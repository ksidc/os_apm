@echo off

echo �������������������� W-18. IIS DB ���� ����� ���� >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%k IN (%TEMP%\IIS_web_name.txt) DO (
	::echo -----------------------------------------------------------------------  >> %TEMP%\File_asa.txt
	echo ����Ʈ�� : %%k >> %TEMP%\File_asa.txt
	%systemroot%\System32\inetsrv\appcmd list config %%k | find /i "add fileExtension" | find /i ".asa" > nul
	if errorlevel 1 (
		echo - .asa .asax Ȯ���� ���͸� ���� ������ �������� ���� >> %TEMP%\File_asa.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%k | find /i "add fileExtension" | find /i ".asa" >> %TEMP%\File_asa.txt
	)
)

FOR /f "delims=" %%i IN (%TEMP%\IIS_web_name.txt) DO (
	::echo -----------------------------------------------------------------------  >> %TEMP%\W-18_Mapping_handler.txt
	echo ����Ʈ�� : %%i >> %TEMP%\W-18_Mapping_handler.txt
	%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.asa \.asax" > nul
	if errorlevel 1 (
		echo - ����� ������ �������� ���� >> %TEMP%\W-18_Mapping_handler.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.asa \.asax" >> %TEMP%\W-18_Mapping_handler.txt
	)
)

type %TEMP%\File_asa.txt | find /i "true" > nul
if errorlevel 1 (
	type %TEMP%\W-18_Mapping_handler.txt | findstr /i "\.asa \.asax" > nul
	if errorlevel 1 (
		echo �� ��� : ��ȣ, ��û ���͸��� .asa .asax Ȯ���ڸ� ������� ������, ó���� ���ο� .asa .asax�� ������� ����	>> %FILENAME%
	) else (
		echo �� ��� : ���, ��û ���͸��� .asa .asax Ȯ���ڸ� ������� ������, ó���� ���ο� .asa .asax�� ����ϰ� ����	>> %FILENAME%
	)
) else (	
	type %TEMP%\W-18_Mapping_handler.txt | findstr /i "\.asa \.asax" > nul
	if errorlevel 1 (
		echo �� ��� : ���, ��û ���͸��� .asa .asax Ȯ���ڸ� ����ϰ� ������, ó���� ���ο� .asa .asax�� ������� ����	>> %FILENAME%
	) else (
		echo �� ��� : ���, ��û ���͸��� .asa .asax Ȯ���ڸ� ����ϰ� ������, ó���� ���ο� .asa .asax�� ����ϰ� ����	>> %FILENAME%
	)
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo ^<��û ���͸�^>	>> %FILENAME%
echo [�⺻ ����] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config | find /i "add fileExtension" | find /i ".asa" > nul
if errorlevel 1 (
	echo - .asa .asax Ȯ���� ���͸� ���� ������ �������� ���� >> %FILENAME%
) else (
	%systemroot%\System32\inetsrv\appcmd list config | find /i "add fileExtension" | find /i ".asa" >> %FILENAME%
)
echo. >> %FILENAME%

echo [����Ʈ�� ����] >> %FILENAME%
type %TEMP%\File_asa.txt >> %FILENAME%
echo. >> %FILENAME%

echo -----------------------------------------------------------------------	>> %FILENAME%
echo ^<ó���� ����^>	>> %FILENAME%
echo [�⺻ ����] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config | find /i "scriptprocessor" | findstr /i "\.asa \.asax" > nul
if errorlevel 1 (
	echo - ����� ������ �������� ���� >> %FILENAME%
) else (
	%systemroot%\System32\inetsrv\appcmd list config | find /i "scriptprocessor" | findstr /i "\.asa \.asax" >> %FILENAME%
)
echo. >> %FILENAME%

echo [����Ʈ�� ����] >> %FILENAME%
type %TEMP%\W-18_Mapping_handler.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%