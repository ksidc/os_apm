@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-58. 터미널 서비스 암호화 수준 설정                              >> %FILENAME%
echo.                              >> %FILENAME%

type Config\%COMPUTERNAME%_Net_Start.txt | find /I "Remote Desktop Services" | find /V "UserMode Port Redirector"  > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 원격 데스크탑 서비스가 구동 중이지 않습니다.                      >> %FILENAME%
	echo.                              >> %FILENAME%
	echo ■ 상세 현황                              >> %FILENAME%
	echo.                              >> %FILENAME%
	type Config\%COMPUTERNAME%_Net_Start.txt | find /I "Remote Desktop Services" | find /V "UserMode Port Redirector"         >> %FILENAME%
	goto W-58_END
)
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server"          > %TEMP%\terminal_temp.txt
type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup" | find "1"  > nul
if errorlevel 1 (
	goto Enable_rdp
) else (
	echo ■ 결과 : 양호, 원격 데스크탑 서비스가 구동 중이나, 연결이 허용되지 않음으로 설정되어 있음                    >> %FILENAME%
	echo.                              >> %FILENAME%
	echo ■ 상세 현황                              >> %FILENAME%
	echo.                              >> %FILENAME%
	type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup" | find "1"          >> %FILENAME%
	goto W-58_END
)
	

:2012_Enable_rdp
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" | find /I "MinEncryptionLevel"  > nul
if errorlevel 1 (
	goto Enable_rdp
)
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" | find /I "MinEncryptionLevel"     > %TEMP%\Terminal_level.txt
FOR /F "tokens=3" %%k in (%TEMP%\Terminal_level.txt) do SET Terminal_level=%%k
if %Terminal_level% GEQ 2 (
	echo ■ 결과 : 양호, 터미널 서비스 암호화 수준을 클라이언트와 호환 가능[중간] 이상으로 설정하고 있음		>> %FILENAME%
) else (
	echo ■ 결과 : 취약, 터미널 서비스 암호화 수준이 낮음으로 설정되어 있음          >> %FILENAME%
)
echo.                              >> %FILENAME%
echo ■ 상세 현황                              >> %FILENAME%
echo.                              >> %FILENAME%
echo [원격 터미널 서비스 암호화 수준 정보]                              >> %FILENAME%
type %TEMP%\Terminal_level.txt                              >> %FILENAME%
if %Terminal_level%==1 set level_info=(낮은 수준)          >> %FILENAME%
if %Terminal_level%==2 set level_info=(중간 수준, 클라이언트와 호환 가능)          >> %FILENAME%
if %Terminal_level%==3 set level_info=(높은 수준)          >> %FILENAME%
echo 암호화 수준 : %Terminal_level% %level_info%          >> %FILENAME%

goto W-58_END


:Enable_rdp
reg query "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Terminal Server\WinStations\RDP-Tcp" | find /I "MinEncryptionLevel"     > %TEMP%\Terminal_level.txt
FOR /F "tokens=3" %%k in (%TEMP%\Terminal_level.txt) do SET Terminal_level=%%k
if %Terminal_level% GEQ 2 (
	echo ■ 결과 : 양호, 터미널 서비스 암호화 수준을 클라이언트와 호환 가능[중간] 이상으로 설정하고 있음		>> %FILENAME%
) else (
	echo ■ 결과 : 취약, 터미널 서비스 암호화 수준이 낮음으로 설정되어 있음          >> %FILENAME%
)
echo.                              >> %FILENAME%
echo ■ 상세 현황                              >> %FILENAME%
echo.                              >> %FILENAME%
echo [원격터미널 서비스 암호화 수준 정보]                              >> %FILENAME%
type %TEMP%\Terminal_level.txt                              >> %FILENAME%
if %Terminal_level%==1 set level_info=(낮은 수준)          >> %FILENAME%
if %Terminal_level%==2 set level_info=(중간 수준, 클라이언트와 호환 가능)          >> %FILENAME%
if %Terminal_level%==3 set level_info=(높은 수준)          >> %FILENAME%
echo 암호화 수준 : %Terminal_level% %level_info%          >> %FILENAME%

:W-58_END
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%


