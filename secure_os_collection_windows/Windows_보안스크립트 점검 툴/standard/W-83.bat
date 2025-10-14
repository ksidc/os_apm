echo --------------------------------수동 점검--------------------------------------------------- >> "%FILENAME%"
echo. >> "%FILENAME%"

:: ================================================
:: 31. Windows Update 자동 업데이트 중지 확인
:: ================================================
echo ▶▶▶▶▶▶▶▶▶▶  Windows Update 자동 업데이트 중지 >> "%FILENAME%"
sc query wuauserv | find "STATE" >> "%FILENAME%"
sc qc wuauserv | find "START_TYPE" >> "%FILENAME%"
sc query WaaSMedicSvc | find "STATE" >> "%FILENAME%"
sc qc WaaSMedicSvc | find "START_TYPE" >> "%FILENAME%"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate >> "%FILENAME%" 2>&1
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** 설명 :  >> "%FILENAME%"
echo - wuauserv, WaaSMedicSvc: STATE = STOPPED, START_TYPE = DISABLED 이어야 정상. >> "%FILENAME%"
echo - NoAutoUpdate = 0x1, AUOptions = 0x1 이면 자동 업데이트 완전 비활성화. >> "%FILENAME%"
echo. >> "%FILENAME%"

:: ================================================
:: 32. 파일 확장자 숨김 해제 확인
:: ================================================
echo ▶▶▶▶▶▶▶▶▶▶ 파일 확장자 숨김 해제 >> "%FILENAME%"
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** 설명 :  >> "%FILENAME%"
echo - HideFileExt = 0x0 이면 "확장자 표시" 활성화로 정상. >> "%FILENAME%"
echo. >> "%FILENAME%"

:: ================================================
:: 33. 이벤트 로그 최대 크기 설정 확인
:: ================================================
echo ▶▶▶▶▶▶▶▶▶▶ 이벤트 로그 최대 크기 설정 >> "%FILENAME%"
echo. >> "%FILENAME%"
echo ** 설명 :  >> "%FILENAME%"
echo - 이벤트 뷰어 - Windows 로그 - 응용프로그램, 시스템, 보안  - 속성 에서 >> "%FILENAME%"
echo 응용프로그램, 시스템 : 20480, 보안 : 40960 확인 >> "%FILENAME%"
echo. >> "%FILENAME%"



:: ================================================
:: 35. WDigest 인증 비활성화 확인
:: ================================================
echo ▶▶▶▶▶▶▶▶▶▶ WDigest 인증 비활성화 >> "%FILENAME%"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** 설명 :  >> "%FILENAME%"
echo - UseLogonCredential = 0x0 이면 비활성화(정상). 0x1 이면 취약 설정. >> "%FILENAME%"
echo. >> "%FILENAME%"


:: ================================================
:: 36. 원격 데스크톱 포트 및 방화벽 허용 확인
:: ================================================
echo ▶▶▶▶▶▶▶▶▶▶ 원격 데스크톱 포트 및 방화벽 규칙 >> "%FILENAME%"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber >> "%FILENAME%" 2>&1
netsh advfirewall firewall show rule name="Allow RDP Port 48321" >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** 설명 :  >> "%FILENAME%"
echo - PortNumber = 48321 이면 포트 변경 정상 적용. >> "%FILENAME%"
echo - 방화벽 규칙 "Allow RDP Port 48321" 가 ENABLED 이면 정상. >> "%FILENAME%"
echo. >> "%FILENAME%"

:: ================================================
:: 37. TCP/RDP 튜닝 설정 확인
:: ================================================
echo ▶▶▶▶▶▶▶▶▶▶TCP/RDP 설정 확인 >> "%FILENAME%"
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay >> "%FILENAME%" 2>&1
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort >> "%FILENAME%" 2>&1
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections >> "%FILENAME%" 2>&1
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fSingleSessionPerUser >> "%FILENAME%" 2>&1
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MaxInstanceCount >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** 설명 :  >> "%FILENAME%"
echo - TcpTimedWaitDelay = 0x1e, MaxUserPort = 0xfffe 가 정상. >> "%FILENAME%"
echo - fDenyTSConnections = 0 ( RDP 허용), fSingleSessionPerUser = 0 (멀티 세션 허용). >> "%FILENAME%"
echo - MaxInstanceCount = 2 (동시 접속 최대 2명) 이면 정상. >> "%FILENAME%"
echo. >> "%FILENAME%"
