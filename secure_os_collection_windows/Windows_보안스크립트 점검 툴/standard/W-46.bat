@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-46. Everyone 사용 권한을 익명 사용자에 적용 해제 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "EveryoneIncludesAnonymous" | Tools\awk.exe -F\ "{print $6}" >> %TEMP%\Everyone_Anonymous.txt
FOR /f "tokens=2 delims=," %%e IN (%TEMP%\Everyone_Anonymous.txt) DO set E_AM=%%e

if %E_AM% EQU 0 echo ■ 결과 : 양호, 'Everyone 사용 권한을 익명 사용자에게 적용' 정책이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
if %E_AM% EQU 1 echo ■ 결과 : 취약, 'Everyone 사용 권한을 익명 사용자에게 적용' 정책이 '사용'으로 설정되어 있음 >> %FILENAME%

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Everyone_Anonymous.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 사용 안 함: 4,0 / 사용: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%