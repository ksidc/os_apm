@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-04. 계정 잠금 임계값 설정 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "LockoutBadCount" >> %TEMP%\Lockout_badcount.txt
FOR /f "tokens=3" %%a IN (%Temp%\Lockout_badcount.txt) DO set L_BAD=%%a

if %L_BAD% EQU 0 (
	echo ■ 결과 : 취약, 계정 잠금 임계값이 설정되지 않음 >> %FILENAME%
) else (
	if %L_BAD% LEQ 5 (
		echo ■ 결과 : 양호, 계정 잠금 임계값이 5 이하의 값으로 설정되어 있음 >> %FILENAME%
	) else (
		echo ■ 결과 : 취약, 계정 잠금 임계값이 5를 초과하는 값으로 설정되어 있음 >> %FILENAME%
	)
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Lockout_badcount.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo ※ 관련 점검 항목: W-47 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%