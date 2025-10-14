@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-42. SAM 계정과 공유의 익명 열거 허용 안 함 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "RestrictAnonymous=" | Tools\awk.exe -F\ "{print $6}" >> %TEMP%\Restrict_anonymous.txt
type %CONFIG%Security_Policy.txt | find /i "RestrictAnonymousSAM" | Tools\awk.exe -F\ "{print $6}" >> %TEMP%\Restrict_anonymous_sam.txt
FOR /f "tokens=2 delims=," %%v IN (%TEMP%\Restrict_anonymous.txt) DO set R_AM=%%v
FOR /f "tokens=2 delims=," %%w IN (%TEMP%\Restrict_anonymous_sam.txt) DO set R_SAM=%%w

if %R_AM% EQU 1 (
	if %R_SAM% EQU 1 (
		echo ■ 결과 : 양호, 'SAM 계정과 공유의 익명 열거 허용 안 함' 및 'SAM 계정의 익명 열거 허용 안 함' 정책이 '사용'으로 설정되어 있음 >> %FILENAME%
	)
	if %R_SAM% EQU 0 (
		echo ■ 결과 : 취약, 'SAM 계정의 익명 열거 허용 안 함' 정책이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
	)	
)
if %R_AM% EQU 0 (
	if %R_SAM% EQU 1 (
		echo ■ 결과 : 취약, 'SAM 계정과 공유의 익명 열거 허용 안 함' 정책이 '사용'으로 설정되어 있음 >> %FILENAME%
	)
	if %R_SAM% EQU 0 (
		echo ■ 결과 : 취약, 'SAM 계정과 공유의 익명 열거 허용 안 함' 및 'SAM 계정의 익명 열거 허용 안 함' 정책이 '사용 안 함'으로 설정되어 있음 >> %FILENAME%
	)	
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [SAM 계정과 공유의 익명 열거 허용 안 함] >> %FILENAME%
type %TEMP%\Restrict_anonymous.txt >> %FILENAME%
echo. >> %FILENAME%
echo [SAM 계정의 익명 열거 허용 안 함] >> %FILENAME%
type %TEMP%\Restrict_anonymous_sam.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 사용 안 함: 4,0 / 사용: 4,1 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%