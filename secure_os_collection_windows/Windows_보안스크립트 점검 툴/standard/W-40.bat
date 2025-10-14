@echo off

echo �������������������� W-40. ���� �ý��ۿ��� ������ �ý��� ���� >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "SeRemoteShutdownPrivilege" | Tools\awk -F= "{print $2}" >> %TEMP%\Shutdown_remote.txt

FOR /f "tokens=1,2,3 delims=," %%e IN (%TEMP%\Shutdown_remote.txt) DO (
	IF %%e GTR "" (
		echo %%e >> %TEMP%\Shutdown_remote_user.txt
	)
	IF %%f GTR "" (
		echo %%f >> %TEMP%\Shutdown_remote_user.txt
	)
	IF %%g GTR "" (
		echo %%g >> %TEMP%\Shutdown_remote_user.txt
	)
)

type %TEMP%\Shutdown_remote_user.txt | find /i /v "S-1-5-32-544" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, '���� �ý��ۿ��� ���� ����' ��å�� 'Administrators' ������ ������ >> %FILENAME%
) else (
	echo �� ��� : ���, '���� �ý��ۿ��� ���� ����' ��å�� 'Administrators' �̿��� �ٸ� �׷� �Ǵ� ������ ������ >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [���� �ý��ۿ��� ���� ����] >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "SeRemoteShutdownPrivilege" >> %FILENAME%

echo. >> %FILENAME%
echo [Administrators �׷� ���� ���] >> %FILENAME%
type %TEMP%\Admin_account.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo �� [�˷��� ����ID ����Ʈ] >> %FILENAME%
echo *S-1-5-32-544 = Administrators >> %FILENAME%
echo *S-1-5-32-545 = Users >> %FILENAME%
echo *S-1-5-32-547 = Power Users >> %FILENAME%
echo *S-1-5-32-555 = Remote Desktop Users >> %FILENAME%
echo *S-1-5-32-551 = Backup Operators >> %FILENAME%
echo *S-1-5-17 = IUSR_[ComputerName] >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%