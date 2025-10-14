@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-47. 계정 잠금 기간 설정 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_policy.txt | findstr /i "LockoutDuration ResetLockoutCount" >> %TEMP%\Lockout_Duration_Reset.txt

for %%f in (%TEMP%\Lockout_Duration_Reset.txt) do (
	if %%~zf EQU 0 (
		echo ■ 결과 : 취약, 계정 잠금 기간 및 다음시간 후 계정 잠금 수를 원래대로 설정을 설정하지 않음 >> %FILENAME%
		echo. >> %FILENAME%
		echo ■ 상세 현황 >> %FILENAME%
		echo. >> %FILENAME%
		echo - LockoutDuration, ResetLockoutCount 값이 존재하지 않음 >> %FILENAME%
	) else (
		echo ■ 결과 : 수동점검, 계정 잠금 기간 및 잠금 유지 기간을 설정하고 있음 >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Lockout_Duration_Reset.txt >> %FILENAME%
			echo. >> %FILENAME%
			echo ※ 주요정보통신기반시설 가이드 기준, 계정 잠금 및 다음시간 후 계정 잠금 수를 원래대로 설정: 60분 이상 권고 >> %FILENAME%
			echo - LockoutDuration=0인 경우 관리자가 명시적으로 잠금을 해제할 때까지 잠긴 상태로 유지됨 >> %FILENAME%
		)
	)
)

echo. >> %FILENAME%
echo ** 설명 :   상기 두 가지 항목 60 이면 양호  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%