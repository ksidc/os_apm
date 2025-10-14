@echo off

echo �������������������� W-28. FTP �������� ���� >> %FILENAME%
echo. >> %FILENAME%

if %FTP_RUN% EQU 0 (
	echo �� ��� : ��ȣ, FTP ���񽺰� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - FTP ���񽺰� ���� ������ ���� >> %FILENAME%
	goto W-08_end
)

if %FTP_RUN% EQU 2 (
	echo �� ��� : ��������, ������ �⺻ FTP �� Ÿ FTP ���� ���������� ���� ���� �ʿ� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %CONFIG%Net_Start.txt | find /i "ftp" >> %FILENAME%
	goto W-08_end
)

:: [FTP_RUN=1]

:: �⺻����
%systemroot%\System32\inetsrv\appcmd list config /section:ipsecurity | find /i "ipAddress" > nul
if errorlevel 1 (
	echo - ���/�ź��� ipAddress�� �������� ���� >> %TEMP%\FTP_acl_reg.txt
) else (
	%systemroot%\System32\inetsrv\appcmd list config /section:ipsecurity | find /i "ipAddress" >> %TEMP%\FTP_acl_reg.txt
)
%systemroot%\System32\inetsrv\appcmd list config /section:ipsecurity | find /i "ipSecurity allowUnlisted" > nul
if errorlevel 1 (
	echo - ipSecurity allowUnlisted ���� ���� �������� ���� >> %TEMP%\FTP_acl_reg.txt
) else (
	%systemroot%\System32\inetsrv\appcmd list config /section:ipsecurity | find /i "ipSecurity allowUnlisted" >> %TEMP%\FTP_acl_reg.txt
)

:: ����Ʈ�� ����
FOR /f "delims=" %%p IN (%TEMP%\FTP_site_name.txt) Do (
	echo -----------------------------------------------------------------------  >> %TEMP%\FTP_acl_site.txt
	echo ����Ʈ�� : %%p >> %TEMP%\FTP_acl_site.txt
	%systemroot%\System32\inetsrv\appcmd list config %%p /section:ipsecurity | find /i "ipAddress" > nul
	if errorlevel 1 (
		echo - ���/�ź��� ipAddress�� �������� ���� >> %TEMP%\FTP_acl_site.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%p /section:ipsecurity | find /i "ipAddress" >> %TEMP%\FTP_acl_site.txt
	)
	%systemroot%\System32\inetsrv\appcmd list config %%p /section:ipsecurity | find /i "ipSecurity allowUnlisted" > nul
	if errorlevel 1 (
		echo - ipSecurity allowUnlisted ���� ���� �������� ���� >> %TEMP%\FTP_acl_site.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%p /section:ipsecurity | find /i "ipSecurity allowUnlisted" >> %TEMP%\FTP_acl_site.txt
	)
)

echo �� ��� : ��������, Ư�� IP �ּҿ����� ���� �����ϵ��� �����Ǿ� �ִ��� Ȯ�� �ʿ� >> %FILENAME%
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [�⺻ ����] >> %FILENAME%
type %TEMP%\FTP_acl_reg.txt >> %FILENAME%
echo. >> %FILENAME%
echo [����Ʈ�� ����] >> %FILENAME%
type %TEMP%\FTP_acl_site.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo �� ����� IP �ּҰ� ��ϵǾ� ������, �������� ���� Ŭ���̾�Ʈ�� ���� �׼���(allowUnlisted)�� �źεǾ�� �� >> %FILENAME%

:W-08_end
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%