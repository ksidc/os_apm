@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-74. 세션 연결을 중단하기 전에 필요한 유휴시간 >> %FILENAME%
echo. >> %FILENAME%
reg query "HKLM\System\CurrentControlSet\Services\LanManServer\Parameters" >> %CONFIG%Session_Reg.txt 2>&1
type Config\%COMPUTERNAME%_Session_Reg.txt | findstr /i "EnableForcedLogoff" > %TEMP%\Session_log.txt
type Config\%COMPUTERNAME%_Session_Reg.txt | findstr /i "AutoDisconnect" > %TEMP%\Session_dis.txt
type %TEMP%\Session_log.txt | findstr /i "EnableForcedLogoff" > nul
if errorlevel 1 (
	echo ■ 결과 : 취약, 로그온 시간이 만료되면 클라이언트 연결 끊기 정책이 설정되어 있지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo EnableForcedLogoff 레지스트리 값이 존재하지 않음 >> %FILENAME%
	goto W-74_END
) else (
	type %TEMP%\Session_log.txt | findstr /i "0x1" > nul
	if errorlevel 1 (
		echo ■ 결과 : 취약, 로그온 시간이 만료되면 클라이언트 연결 끊기 정책이 사용 안 함 으로 설정되어 있음 >> %FILENAME%
		echo. >> %FILENAME%
		echo ■ 상세 현황 >> %FILENAME%
		type %TEMP%\Session_log.txt >> %FILENAME%
		goto W-74_END
	) else (
		echo [로그온 시간이 만료되면 클라이언트 연결 끊기] > %TEMP%\Session_policy.txt
		type %TEMP%\Session_log.txt >> %TEMP%\Session_policy.txt
		echo. >> %TEMP%\Session_policy.txt
		echo [세션 연결을 중단하기 전에 필요한 유휴 시간] >> %TEMP%\Session_policy.txt	
		type %TEMP%\Session_dis.txt | findstr /i "AutoDisconnect" > nul
		if errorlevel 1 (
			echo ■ 결과 : 양호, 세션 연결을 중단하기 전에 필요한 유휴 시간 정책이 설정되어 있지 않음 >> %FILENAME%
			echo AutoDisconnect가 정의되어 있지 않으므로 Default 값인 15분으로 간주 >> %TEMP%\Session_policy.txt
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			type %TEMP%\Session_policy.txt >> %FILENAME%
			goto W-74_END
		) else (
			type %TEMP%\Session_dis.txt >> %TEMP%\Session_policy.txt
			goto W-74_Check
		)
	)
)

:W-74_Check
For /F "tokens=3" %%e in (Temp\Session_dis.txt) Do set A_TEMP=%%e
set /a B_TEMP=%A_TEMP%

if %A_TEMP% GTR 15 (
	echo ■ 결과 : 취약, 세션 연결을 중단하기 전에 필요한 유휴 시간 정책이 %B_TEMP%분으로 설정되어 있음 >> %FILENAME%	
) else (
	echo ■ 결과 : 양호, 세션 연결을 중단하기 전에 필요한 유휴 시간 정책이 15분 이하로 설정되어 있음 >> %FILENAME%
)
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
type %TEMP%\Session_policy.txt >> %FILENAME%

:W-74_END
echo.  	>> %FILENAME%  
echo.  	>> %FILENAME%
echo.  	>> %FILENAME%