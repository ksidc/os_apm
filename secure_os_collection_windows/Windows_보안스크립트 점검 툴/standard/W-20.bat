@echo off

echo �������������������� W-20. IIS ������ ���� ACL ���� >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%j IN (%TEMP%\IIS_root_path.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Data_file_acl.txt
	echo Ȩ ���丮 ��� : %%j >> %TEMP%\Data_file_acl.txt
	echo. >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.exe /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.dll /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.cmd /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.pl /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.asp /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.inc /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.shtm /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.shtml /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.txt /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.gif /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.jpg /t 2> nul >> %TEMP%\Data_file_acl.txt
	cacls %%~fj\*.html /t 2> nul >> %TEMP%\Data_file_acl.txt
)

type %TEMP%\Data_file_acl.txt | find /i "Everyone:" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, IIS Ȩ ���丮 ���� Everyone ������ ������ ������ �������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo - Everyone ������ ������ ������ �������� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, IIS Ȩ ���丮 ���� Everyone ������ ������ ������ ������ >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\Data_file_acl.txt | find /i "Everyone" >> %FILENAME%
)

echo. >> %FILENAME%
echo �� IIS Ȩ ���丮 �� ���ϵ��� ���� ���� �� ��Ȳ�� %TEMP%\Data_file_acl.txt ���� ���� >> %FILENAME%
echo    exe, dll, cmd, pl, asp, inc, shtm, shtml, txt, gif, jpg, html Ȯ���ڸ� ������� ������ ������ >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%