@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-57. 원격터미널 접속 가능한 사용자 그룹 제한                              >> %FILENAME%
echo.                              		>> %FILENAME%
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server"             >> %TEMP%\terminal_temp.txt
type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup" | find "0x1"  > nul
if errorlevel 1 (
	echo ■ 결과 : 수동 점검, "원격 데스크톱 서비스를 통한 로그인 허용 가능 그룹" 내 불필요한 그룹 및 계정 등록 여부 점검          >> %FILENAME%
	echo.                             	>> %FILENAME%
	echo ■ 상세 현황                      	>> %FILENAME%
	echo.                              	>> %FILENAME%
	echo [원격 데스크톱 서비스 연결 허용 여부]		>> %FILENAME%
	type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup"          >> %FILENAME%
	echo.                              				>> %FILENAME%
	echo [원격 데스크톱 서비스를 통한 로그인 허용 가능 그룹 확인]		>> %FILENAME%
	type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "SeRemoteInteractiveLogonRight"          >> %FILENAME%
	echo.                              				>> %FILENAME%
	
	echo [Administrators Group 구성원 확인 - Everyone과 유사하므로 해당 그룹 존재 시 취약]                           >> %FILENAME%
	net localgroup Administrators | find /i /v "Alias name" | find /i /v "comment" | find /i /v "members" | find /i /v "completed" | find /i /v "-"  >> %FILENAME%
	
	echo [Remote Desktop Users Group 구성원 확인]       >> %FILENAME%
	net localgroup "Remote Desktop Users" | find /i /v "Alias name" | find /i /v "comment" | find /i /v "members" | find /i /v "completed" | find /i /v "-"  >> %FILENAME%
) else (
	echo ■ 결과 : 양호, 원격 데스크톱 서비스가 "연결 허용 안됨"으로 설정되어 있음          >> %FILENAME%
	echo.                              >> %FILENAME%
	echo ■ 상세 현황                      >> %FILENAME%
	echo.                              >> %FILENAME%
	echo [원격 데스크톱 서비스 연결 허용 여부]     >> %FILENAME%
	type %TEMP%\terminal_temp.txt | find /i "fDenyTSConnections" | find /i /v "fDenyTSConnectionsBackup"          >> %FILENAME%
	echo.                              >> %FILENAME%
	echo 원격 데스크톱 서비스 연결이 허용되지 않음으로 설정되어 있습니다.					>> %FILENAME%	
) 

echo. >> %FILENAME%
echo ** 설명 :  SeRemoteInteractiveLogonRight = *S-1-5-32-544,*S-1-5-32-555 이면 양호 >> %FILENAME%
echo 상기 구성원에 불필요한 계정이 있는지 확인>> %FILENAME%


echo.             	>> %FILENAME%
echo.             	>> %FILENAME%
echo.            	>> %FILENAME%	