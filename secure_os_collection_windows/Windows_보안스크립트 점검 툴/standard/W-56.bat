@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-56. 콘솔 로그온 시 로컬 계정에서 빈 암호 사용 제한                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "LimitBlankPasswordUse" | find "4,1"  > nul
if errorlevel 1 (
	echo ■ 결과 : 취약, “콘솔 로그온 시 로컬 계정에서 빈 암호 사용 제한” 정책이 “사용 안 함”으로 되어 있음          >> %FILENAME%
) else (
	echo ■ 결과 : 양호, “콘솔 로그온 시 로컬 계정에서 빈 암호 사용 제한” 정책이 “사용”으로 되어 있음          >> %FILENAME%
)
echo.                              >> %FILENAME%
echo ■ 상세 현황                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "LimitBlankPasswordUse"	| Tools\awk.exe -F\ "{print $6}"          >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%