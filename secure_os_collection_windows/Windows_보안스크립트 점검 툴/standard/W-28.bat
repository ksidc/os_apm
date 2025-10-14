@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-28. FTP 접근제어 설정 >> %FILENAME%
echo. >> %FILENAME%

if %FTP_RUN% EQU 0 (
	echo ■ 결과 : 양호, FTP 서비스가 비활성화되어 있음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo - FTP 서비스가 구동 중이지 않음 >> %FILENAME%
	goto W-08_end
)

if %FTP_RUN% EQU 2 (
	echo ■ 결과 : 수동점검, 윈도우 기본 FTP 외 타 FTP 서비스 구동중으로 별도 점검 필요 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	type %CONFIG%Net_Start.txt | find /i "ftp" >> %FILENAME%
	goto W-08_end
)

:: [FTP_RUN=1]

:: 기본설정
%systemroot%\System32\inetsrv\appcmd list config /section:ipsecurity | find /i "ipAddress" > nul
if errorlevel 1 (
	echo - 허용/거부할 ipAddress가 존재하지 않음 >> %TEMP%\FTP_acl_reg.txt
) else (
	%systemroot%\System32\inetsrv\appcmd list config /section:ipsecurity | find /i "ipAddress" >> %TEMP%\FTP_acl_reg.txt
)
%systemroot%\System32\inetsrv\appcmd list config /section:ipsecurity | find /i "ipSecurity allowUnlisted" > nul
if errorlevel 1 (
	echo - ipSecurity allowUnlisted 설정 값이 존재하지 않음 >> %TEMP%\FTP_acl_reg.txt
) else (
	%systemroot%\System32\inetsrv\appcmd list config /section:ipsecurity | find /i "ipSecurity allowUnlisted" >> %TEMP%\FTP_acl_reg.txt
)

:: 사이트별 설정
FOR /f "delims=" %%p IN (%TEMP%\FTP_site_name.txt) Do (
	echo -----------------------------------------------------------------------  >> %TEMP%\FTP_acl_site.txt
	echo 사이트명 : %%p >> %TEMP%\FTP_acl_site.txt
	%systemroot%\System32\inetsrv\appcmd list config %%p /section:ipsecurity | find /i "ipAddress" > nul
	if errorlevel 1 (
		echo - 허용/거부할 ipAddress가 존재하지 않음 >> %TEMP%\FTP_acl_site.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%p /section:ipsecurity | find /i "ipAddress" >> %TEMP%\FTP_acl_site.txt
	)
	%systemroot%\System32\inetsrv\appcmd list config %%p /section:ipsecurity | find /i "ipSecurity allowUnlisted" > nul
	if errorlevel 1 (
		echo - ipSecurity allowUnlisted 설정 값이 존재하지 않음 >> %TEMP%\FTP_acl_site.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%p /section:ipsecurity | find /i "ipSecurity allowUnlisted" >> %TEMP%\FTP_acl_site.txt
	)
)

echo ■ 결과 : 수동점검, 특정 IP 주소에서만 접속 가능하도록 설정되어 있는지 확인 필요 >> %FILENAME%
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [기본 설정] >> %FILENAME%
type %TEMP%\FTP_acl_reg.txt >> %FILENAME%
echo. >> %FILENAME%
echo [사이트별 설정] >> %FILENAME%
type %TEMP%\FTP_acl_site.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo ※ 허용할 IP 주소가 등록되어 있으며, 지정되지 않은 클라이언트에 대한 액세스(allowUnlisted)는 거부되어야 함 >> %FILENAME%

:W-08_end
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%