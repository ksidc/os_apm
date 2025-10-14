@echo off
echo ▶▶▶▶▶▶▶▶▶▶ W-67. 원격터미널 접속 타임아웃 설정 >> %FILENAME%
echo. >> %FILENAME%

reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" | findstr /i "fDenyTSConnections"	| findstr /i "0x0" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 원격 터미널 서비스가 비활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" | findstr /i "fDenyTSConnections" >> %FILENAME%
) else (
	reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" > %TEMP%\Remote_temp.txt
	type %TEMP%\Remote_temp.txt | findstr /i "MaxIdleTime" > nul
	if errorlevel 1 (
		echo ■ 결과 : 취약, 활성 상태지만 유휴 터미널 서비스 세션에 시간 제한 설정 정책이 구성되지 않음 >> %FILENAME%
		echo. >> %FILENAME%	
		echo ■ 상세 현황 >> %FILENAME%	
		echo. >> %FILENAME%
		echo - MaxIdleTime 레지스트리 값이 존재하지 않음 >> %FILENAME%	
	) else (
		type %TEMP%\Remote_temp.txt | findstr /i "MaxIdleTime" > %TEMP%\Remote_idletime.txt
		type %TEMP%\Remote_idletime.txt | findstr /i "0x0" > nul
		if errorlevel 1 (
			echo ■ 결과 : 양호, Session Timeout이 설정되어 있음 >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Remote_idletime.txt >> %FILENAME%
		) else (
			echo ■ 결과 : 취약, 활성 상태지만 유휴 터미널 서비스 세션에 시간 제한 설정 정책이 사용 안 함 으로 설정 되어 있음 >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Remote_idletime.txt >> %FILENAME%
		)
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%