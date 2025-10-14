@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-30. RDS(Remote Data Services)제거 >> %FILENAME%
echo. >> %FILENAME%

if %IIS_RUN% EQU 0 (
	echo ■ 결과 : 양호, IIS 서비스가 비활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - IIS 서비스가 구동 중이지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 양호, Windows Server 2008 이상 버전에서는 해당 항목의 취약점이 존재하지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo [Windows 버전] >> %FILENAME%
	type %CONFIG%System_Info.txt | find /i "OS" | findstr /i "Name Version" | findstr /i /v "Host BIOS" >> %FILENAME%
	echo. >> %FILENAME%
	echo ※ Windows 2000 Service Pack 4, Windows 2003 Service Pack 2, Windows 2008 이상 설치되어 있는 경우 양호 >> %FILENAME%
	echo    위 버전보다 낮은 버전의 Windows를 사용하고 있는 경우 별도 점검 필요 >> %FILENAME%
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%