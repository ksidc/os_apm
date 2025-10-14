@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-05. 해독 가능한 암호화를 사용하여 암호 저장 해제 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "ClearTextPassword" | find "0" > nul
if errorlevel 1 (
	echo ■ 결과 : 취약, '해독 가능한 암호화를 사용하여 암호 저장' 정책이 '사용'으로 설정되어 있음 >> %FILENAME%
) else (
	echo ■ 결과 : 양호, '해독 가능한 암호화를 사용하여 암호 저장' 정책이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%Security_Policy.txt | find /i "ClearTextPassword" >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%