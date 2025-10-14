@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-29. DNS Zone Transfer 설정 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Net_Start.txt | find /i "DNS Server" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, DNS 서비스가 비활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - DNS Server 서비스가 구동 중이지 않음 >> %FILENAME%	
) else (
	reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones" | find /i /v "TrustAnchors" | findstr .  > nul
	if errorlevel 1 (
		echo ■ 결과 : 취약, DNS 정/역방향 조회 영역이 생성되어 있지 않으므로 DNS 서비스를 사용하지 않을 경우 중지할 것을 권고 >> %FILENAME%
		echo. >> %FILENAME%
		echo ■ 상세 현황 >> %FILENAME%
		echo. >> %FILENAME%
		echo - DNS 조회 영역이 존재하지 않음 >> %FILENAME%
	) else (
		reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DNS Server\Zones" | find /i /v "TrustAnchors" >> %TEMP%\DNS_zone_name.txt
		FOR /f "delims=" %%a IN (%TEMP%\DNS_zone_name.txt) DO (
			reg query "%%a" >> %CONFIG%DNS_zones.txt
			reg query "%%a" | find /i "SecureSecondaries" | findstr /i "x0 x1" > nul
			if errorlevel 1 (
				echo 영역 전송 레지스트리 값이 2 또는 3으로 설정되어 있음 > nul
			) else (
				reg query "%%a" | findstr /i "HKEY DatabaseFile SecureSecondaries" >> %TEMP%\DNS_zone_transfer.txt
				echo. >> %TEMP%\DNS_zone_transfer.txt
			)
		)
		if exist %TEMP%\DNS_zone_transfer.txt (
			echo ■ 결과 : 취약, 영역 전송이 '아무 서버로' 또는 '이름 서버 탭에 나열된 서버로만' 으로 설정되어 있음 >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\DNS_zone_transfer.txt >> %FILENAME%
		) else (
			echo ■ 결과 : 양호, 영역 전송을 허용하지 않거나 특정 서버로만 전송하도록 설정되어 있음 >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			type %CONFIG%DNS_zones.txt | find /i "SecureSecondaries" >> %FILENAME%
		)
		echo. >> %FILENAME%
		echo. >> %FILENAME%
		echo ※ SecureSecondaries - 0x3: 영역 전송 허용 안 함, 0x2: 다음 서버로만, 0x1: 이름 서버 탭에 나열된 서버로만, 0x0: 아무 서버로 >> %FILENAME%
		echo    DNS 조회 영역 관련 상세 레지스트리 현황은 %CONFIG%DNS_zones.txt 파일 참조 >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%