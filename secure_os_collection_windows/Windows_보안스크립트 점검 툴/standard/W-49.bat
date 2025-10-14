@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-49. 패스워드 최소 암호 길이 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "MinimumPasswordLength" >> %TEMP%\Password_minlen.txt
FOR /f "tokens=3" %%g IN (%Temp%\Password_minlen.txt) DO set P_LEN=%%g

if %P_LEN% GEQ 8 (
	echo ■ 결과 : 양호, 최소 암호 길이가 8문자 이상으로 설정되어 있음 >> %FILENAME%
) else (
	if %P_LEN% EQU 0 (
		echo ■ 결과 : 취약, '암호 필요 없음'으로 설정되어 있음 >> %FILENAME%
	) else (
		echo ■ 결과 : 취약, 최소 암호 길이가 8문자 미만으로 설정되어 있음 >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Password_minlen.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%