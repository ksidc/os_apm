@echo off

echo �������������������� W-37. SAM ���� ���� ���� ���� >> %FILENAME%
echo. >> %FILENAME%

cacls %systemroot%\system32\config\SAM >> %TEMP%\SAM_file_acl.txt

type %TEMP%\SAM_file_acl.txt | find /i /v "NT AUTHORITY\SYSTEM" | find /i /v "BUILTIN\Administrators" | find "\" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, SAM ���� ���ٱ��ѿ� Administrators, System �׷츸 ������ >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\SAM_file_acl.txt >> %FILENAME%	
) else (
	echo �� ��� : ��������, SAM ���� ���ٱ��ѿ� Administrator, System �׷� �̿� �ٸ� ���� ���� ���� Ȯ�� �ʿ� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\SAM_file_acl.txt >> %FILENAME%
	echo. >> %FILENAME%
	echo [������ �׷� ���� ���] >> %FILENAME%
	type %TEMP%\Admin_account.txt >> %FILENAME%
)

echo. >> %FILENAME%
echo �� ������ �׷� �� ��Ȳ�� W-06 ���� �׸��� ���� >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%