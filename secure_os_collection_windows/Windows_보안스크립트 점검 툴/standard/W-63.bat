@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-63. DNS 서비스 구동 점검 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Net_Start.txt | find /i "DNS Server" > nul
if errorlevel 1 ( 
	echo ■ 결과 : 양호, DNS 서비스가 비활성화 되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%	
) else (
	reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones" /s | find /i "AllowUpdate" >> %TEMP%\win_63.txt
	type %TEMP%\win_63.txt | find /i "AllowUpdate" | find "1" > nul
	if errorlevel 1 (
		echo ■ 결과 : 양호, DNS 서비스가 구동중이나, 동적 업데이트 "없음"으로 설정되어 있음 >> %FILENAME%
	) else (
		echo ■ 결과 : 취약, 동적 업데이트가 설정된 DNS 영역이 존재함 >> %FILENAME%
	)
	echo. >> %FILENAME%	
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %TEMP%\win_63.txt | find /i "AllowUpdate" >> %FILENAME%
	)
)
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
