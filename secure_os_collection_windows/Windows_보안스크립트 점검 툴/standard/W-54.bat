@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-54. 익명 SID/이름 변환 허용                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "LSAAnonymousNameLookup" | Find "0"  > nul
if errorlevel 1 (
	echo ■ 결과 : 취약, “익명 SID/이름 변환 허용” 정책이 “사용” 으로 되어 있음						>> %FILENAME%
) else (
	echo ■ 결과 : 양호, “익명 SID/이름 변환 허용” 정책이 “사용 안 함” 으로 되어 있음					>> %FILENAME%
)
echo.                              >> %FILENAME%
echo ■ 상세 현황                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "LSAAnonymousNameLookup"          >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
