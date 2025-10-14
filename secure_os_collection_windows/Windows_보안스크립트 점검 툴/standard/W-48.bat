@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-48. 패스워드 복잡성 설정 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "PasswordComplexity" >> %TEMP%\Password_complex.txt
FOR /f "tokens=3" %%f IN (%Temp%\Password_complex.txt) DO set P_COM=%%f

if %P_COM% EQU 0 echo ■ 결과 : 취약, '암호는 복잡성을 만족해야 함' 정책이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
if %P_COM% EQU 1 echo ■ 결과 : 양호, '암호는 복잡성을 만족해야 함' 정책이 '사용'으로 설정되어 있음 >> %FILENAME%

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Password_complex.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%