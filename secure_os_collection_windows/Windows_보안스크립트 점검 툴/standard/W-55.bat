@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-55. 최근 암호 기억                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "history"          > %TEMP%\pw_history.txt
FOR /F "tokens=3" %%i IN (%TEMP%\pw_history.txt) DO set history_temp=%%i
if %history_temp% GEQ 12 (
	echo ■ 결과 : 양호, 최근 암호 기억이 12개 이상으로 설정되어 있음          >> %FILENAME%
) else (
	echo ■ 결과 : 취약, 최근 암호 기억이 12개 미만으로 설정되어 있음          >> %FILENAME%
)

echo.                              >> %FILENAME%
echo ■ 상세 현황                              >> %FILENAME%
echo.                              >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | find /I "history"                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
echo.                              >> %FILENAME%
