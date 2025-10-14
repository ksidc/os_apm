@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-03. 불필요한 계정 제거 >> %FILENAME%
echo. >> %FILENAME%

echo ■ 결과 : 수동점검, 불필요한 계정 존재 여부 점검 >> %FILENAME%
wmic useraccount get name | findstr /v /i "Name" > %TEMP%\User_name.txt

FOR /F "tokens=1,2,3" %%j IN (%TEMP%\User_name.txt) DO (
	IF %%j GTR "" (
		net user %%j | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active.txt
			net user %%j >> %CONFIG%User_active.txt
		) else (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active_no.txt
			net user %%j >> %CONFIG%User_active_no.txt
		)
	)
	IF %%k GTR "" (
		net user %%k | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active.txt
			net user %%k >> %CONFIG%User_active.txt
		) else (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active_no.txt
			net user %%k >> %CONFIG%User_active_no.txt
		)
	)
	IF %%l GTR "" (
		net user %%l | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active.txt
			net user %%l >> %CONFIG%User_active.txt
		) else (
			echo ----------------------------------------------------------------------- >> %CONFIG%User_active_no.txt
			net user %%l >> %CONFIG%User_active_no.txt
		)
	)
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [사용자 계정 목록] >> %FILENAME%
type %TEMP%\User_name.txt >> %FILENAME%
echo [계정별 패스워드 변경 내역 확인] >> %FILENAME%
type %CONFIG%User_active.txt | findstr /i "\----- Name Last" | find /i /v "Full" >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo ※ 상세 계정 정보는 %CONFIG%User_active.txt 파일 참고 >> %FILENAME%

echo. >> %FILENAME%
echo ** 설명 :  상기 확인 된 계정 중 불필요한 계정 확인 >> %FILENAME%
echo (DefaultAccount, Guest, WDAGUtilityAccount은 기본 계정)  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%