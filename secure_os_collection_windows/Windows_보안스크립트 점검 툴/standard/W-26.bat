@echo off

echo �������������������� W-26. FTP ���丮 ���ٱ��� ���� >> %FILENAME%
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
		type %TEMP%\FTP_path_acl.txt | find /i "Everyone" > nul
		if errorlevel 1 (
			echo �� ��� : ��ȣ, FTP Ȩ ���丮�� Everyone ��� ������ �������� ����  >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP ����Ʈ] >> %FILENAME%
			type %CONFIG%FTP_SiteList.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP ����Ʈ Ȩ���丮] >> %FILENAME%
			type %TEMP%\FTP_homedir.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP ����Ʈ�� Ȩ���丮 ���ٱ���] >> %FILENAME%
			type %TEMP%\FTP_path_acl.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo - Everyone ��� ������ �������� ���� >> %FILENAME%
		) else (
			echo �� ��� : ���, FTP Ȩ ���丮�� Everyone ��� ������ �����Ǿ� ����  >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP ����Ʈ] >> %FILENAME%
			type %CONFIG%FTP_SiteList.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP ����Ʈ Ȩ���丮] >> %FILENAME%
			type %TEMP%\FTP_homedir.txt	>> %FILENAME%
			echo. >> %FILENAME%
			echo [FTP ����Ʈ�� Ȩ���丮 ���ٱ���] >> %FILENAME%
			type %TEMP%\FTP_path_acl.txt	>> %FILENAME%
		)
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%