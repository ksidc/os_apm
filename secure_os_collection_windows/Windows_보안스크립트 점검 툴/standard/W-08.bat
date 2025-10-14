@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-08. 하드디스크 기본 공유 제거 >> %FILENAME%
echo. >> %FILENAME%

TYPE %CONFIG%NetShare_Info.txt | find /v "IPC$" | find /i "$" | findstr /v /i "PRINT FAX" > nul
if errorlevel 1 (
	set share=0
	reg query "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" | findstr /i "AutoShareServer AutoShareWks" > %TEMP%\Netshare_reg.txt
	TYPE %TEMP%\Netshare_reg.txt | find "0x0" > nul
	if errorlevel 1 (
		echo ■ 결과 : 취약, 기본 공유는 제거되어 있으나, AutoShareServer가 설정되지 않음 >> %FILENAME%
	) else (
		echo ■ 결과 : 양호, 기본 공유가 제거되어 있으며, AutoShareServer가 설정되어 있음 >> %FILENAME%
	)
) else (
	set share=1
	echo ■ 결과 : 취약, 기본 공유가 존재함 >> %FILENAME%
)
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [하드디스크 기본 공유 목록] >> %FILENAME%
if %share% EQU 0 (
	echo - 기본 공유가 존재하지 않음 >> %FILENAME%
	echo. >> %FILENAME%
	echo [레지스트리 설정] >> %FILENAME%
	TYPE %TEMP%\Netshare_reg.txt | findstr /i "AutoShareServer AutoShareWks" > nul
	if errorlevel 1 (
		echo - AutoShareServer 레지스트리 값이 존재하지 않음 >> %FILENAME%
	) else (
		echo HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters >> %FILENAME%
		TYPE %TEMP%\Netshare_reg.txt >> %FILENAME%
	)
) else (
	type %CONFIG%NetShare_Info.txt | find /v "IPC$" | find /i "$" | findstr /v /i "PRINT FAX" >> %FILENAME%
)

echo. >> %FILENAME%
echo ※ 하드디스크 공유 상세 현황은 %CONFIG%NetShare_Info.txt 파일 참고 >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%