@echo off
set temp2=0
set temp3=0
echo ▶▶▶▶▶▶▶▶▶▶ W-70. 이벤트 로그 관리 설정	>> %FILENAME%
echo.	>> %FILENAME%
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Eventlog\Application" | findstr /I "MaxSize"	> %TEMP%\eventlog.txt
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Eventlog\System" | findstr /I "MaxSize"	>> %TEMP%\eventlog.txt
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Eventlog\Security" | findstr /I "MaxSize"	>> %TEMP%\eventlog.txt

reg query "HKLM\SYSTEM\CurrentControlSet\Services\Eventlog\Application" | findstr /I "Retention"	> %TEMP%\eventlog2.txt
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Eventlog\System" | findstr /I "Retention"	>> %TEMP%\eventlog2.txt
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Eventlog\Security" | findstr /I "Retention"	>> %TEMP%\eventlog2.txt
for /F "tokens=3 delims= " %%i in (%TEMP%\eventlog.txt) do (
	if %%i LEQ 0xa00000 (
		set /a temp2+=0
	) else (
		set /a temp2+=1
	)
)
for /F "tokens=3 delims= " %%i in (%TEMP%\eventlog2.txt) do (
	if %%i EQU 0x0 (
		set /a temp3+=0
	) else (
		set /a temp3+=1
	)
)

if %temp3% LSS 3 (
	echo ■ 결과 : 취약, 이벤트로그 덮어쓰기 설정이 미흡함         >> %FILENAME%
) else (
	if %temp2% LSS 3 (
		echo ■ 결과 : 취약, 이벤트로그 최대 크기가 10,240kb 미만으로 설정되어 있음         >> %FILENAME%
	) else (
		echo ■ 결과 : 양호, 이벤트로그 최대 크기가 10,240kb 이상으로 설정되어 있음         >> %FILENAME%
	)
)

echo.	>> %FILENAME%
echo ■ 상세 현황		>> %FILENAME%
echo.	>> %FILENAME%
echo [이벤트 로그 덮어쓰기 설정 (응용프로그램/시스템/보안)]	>> %FILENAME%
type %TEMP%\eventlog2.txt 	>> %FILENAME%
echo.	>> %FILENAME%
echo [이벤트 크기 설정 (응용프로그램/시스템/보안)]	>> %FILENAME%
type %TEMP%\eventlog.txt 	>> %FILENAME%

echo. >> %FILENAME%
echo ** 설명 :  이벤트 뷰어 - Windows 로그 -  속성  :  필요한 경우 이벤트 덮어쓰기면 양호  >> %FILENAME%
echo 상기 Maxsize 3개 0x1400000, 0x2800000 이면 양호 >> %FILENAME%

echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%