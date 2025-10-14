@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-51. 패스워드 최소 사용 기간 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "MinimumPasswordAge" >> %TEMP%\Password_minage.txt
FOR /f "tokens=3" %%i IN (%Temp%\Password_minage.txt) DO set P_MIN=%%i

if %P_MIN% EQU 0 echo ■ 결과 : 취약, 최소 암호 사용 기간이 설정되지 않음 >> %FILENAME%
if %P_MIN% GEQ 1 echo ■ 결과 : 양호, 최소 암호 사용 기간이 1일 이상으로 설정되어 있음 >> %FILENAME%

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Password_minage.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%
