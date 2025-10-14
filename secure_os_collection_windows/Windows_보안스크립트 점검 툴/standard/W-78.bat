@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-78. 보안 채널 데이터 디지털 암호화 또는 서명	>> %FILENAME%
echo. 	>> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "RequireSignOrSeal SealSecureChannel SignSecureChannel" | findstr "4,0" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 보안 채널 데이터 디지털 암호화 또는 서명 관련 정책 모두 "사용" 설정되어 있음			>> %FILENAME%
) else (
	echo ■ 결과 : 취약, 보안 채널 데이터 디지털 암호화 또는 서명 정책 설정이 미흡함			>> %FILENAME%
)

echo. 	>> %FILENAME%
echo ■ 상세 현황	>> %FILENAME%
echo. 	>> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "RequireSignOrSeal SealSecureChannel SignSecureChannel" | Tools\awk.exe -F\ "{print $7}"	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%