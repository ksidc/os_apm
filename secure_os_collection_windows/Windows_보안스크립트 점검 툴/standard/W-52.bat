@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-52. 마지막 사용자 이름 표시 안함 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "DontDisplayLastUserName" | Tools\awk.exe -F\ "{print $8}" >> %TEMP%\Display_lastuser.txt
FOR /f "tokens=2 delims=," %%j IN (%TEMP%\Display_lastuser.txt) DO set D_LAST=%%j

if %D_LAST% EQU 0 echo ■ 결과 : 취약, '마지막 사용자 이름 표시 안 함' 정책이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
if %D_LAST% EQU 1 echo ■ 결과 : 양호, '마지막 사용자 이름 표시 안 함' 정책이 '사용'으로 설정되어 있음 >> %FILENAME%

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Display_lastuser.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 사용 안 함: 4,0 / 사용: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%