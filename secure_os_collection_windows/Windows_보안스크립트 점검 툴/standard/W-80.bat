@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-80. 컴퓨터 계정 암호 최대 사용 기간 >> %FILENAME%
echo. >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /i "\disablepasswordchange" > %TEMP%\Disable_pwchange.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /i "\MaximumPasswordAge" > %TEMP%\Maximum_pwage.txt

for /F "tokens=2 delims=," %%a in (%TEMP%\Disable_pwchange.txt) do set PW_CH=%%a
for /F "tokens=2 delims=," %%b in (%TEMP%\Maximum_pwage.txt) do set PW_AGE=%%b

if "%PW_CH%"=="1" (
	echo ■ 결과 : 취약, 컴퓨터 계정 암호 변경 사용 안 함 정책이 사용으로 설정되어 있어 계정 암호 최대 사용 기간이 적용되지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo [컴퓨터 계정 암호 변경 사용 안 함] >> %FILENAME%
	type %TEMP%\Disable_pwchange.txt | Tools\awk.exe -F\ "{print $7}" >> %FILENAME%
) else (
	if %PW_AGE% GEQ 1 if %PW_AGE% LEQ 90 echo ■ 결과 : 양호, 컴퓨터 계정 암호 최대 사용기간이 90일 이하로 설정되어 있음 >> %FILENAME%
	if %PW_AGE% GTR 90 echo ■ 결과 : 취약, 컴퓨터 계정 암호 최대 사용 기간이 90일을 초과한 값으로 설정되어 있음 >> %FILENAME%
	if "%PW_AGE%"=="0" echo ■ 결과 : 취약, 컴퓨터 계정 암호 최대 사용 기간이 0일로 설정되어 암호가 만료되지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo ■ 상세 현황 >> %FILENAME%
	echo. >> %FILENAME%
	echo [컴퓨터 계정 암호 변경 사용 안 함] >> %FILENAME%
	type %TEMP%\Disable_pwchange.txt | Tools\awk.exe -F\ "{print $7}" >> %FILENAME%
	echo. >> %FILENAME%
	echo [컴퓨터 계정 암호 최대 사용 기간] >> %FILENAME%
	type %TEMP%\Maximum_pwage.txt | Tools\awk.exe -F\ "{print $7}" >> %FILENAME%	
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%