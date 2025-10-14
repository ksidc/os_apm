@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-50. 패스워드 최대 사용 기간 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "MaximumPasswordAge" >> %TEMP%\Password_maxage.txt
FOR /f "tokens=3" %%h IN (%Temp%\Password_maxage.txt) DO set P_MAX=%%h

if %P_MAX% LEQ 90 (
	if %P_MAX% EQU 0 (
		echo ■ 결과 : 취약, 최대 암호 사용 기간이 설정되지 않음 >> %FILENAME%
	) else (
		echo ■ 결과 : 양호, 최대 암호 사용 기간이 90일 이하로 설정되어 있음 >> %FILENAME%
	)
) else (
	echo ■ 결과 : 취약, 최대 암호 사용 기간이 90일을 초과하여 설정되어 있음 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Password_maxage.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%