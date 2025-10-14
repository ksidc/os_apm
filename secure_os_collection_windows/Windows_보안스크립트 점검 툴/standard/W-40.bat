@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-40. 원격 시스템에서 강제로 시스템 종료 >> %FILENAME%
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
	echo ■ 결과 : 양호, '원격 시스템에서 강제 종료' 정책에 'Administrators' 계정만 존재함 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, '원격 시스템에서 강제 종료' 정책에 'Administrators' 이외의 다른 그룹 또는 계정이 존재함 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [원격 시스템에서 강제 종료] >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "SeRemoteShutdownPrivilege" >> %FILENAME%

echo. >> %FILENAME%
echo [Administrators 그룹 계정 목록] >> %FILENAME%
type %TEMP%\Admin_account.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo ※ [알려진 로컬ID 리스트] >> %FILENAME%
echo *S-1-5-32-544 = Administrators >> %FILENAME%
echo *S-1-5-32-545 = Users >> %FILENAME%
echo *S-1-5-32-547 = Power Users >> %FILENAME%
echo *S-1-5-32-555 = Remote Desktop Users >> %FILENAME%
echo *S-1-5-32-551 = Backup Operators >> %FILENAME%
echo *S-1-5-17 = IUSR_[ComputerName] >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%