@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-38. 화면보호기 설정 >> %FILENAME%
echo. >> %FILENAME%

:: 화면보호기 설정 확인
reg query "HKCU\Control Panel\Desktop" /f "ScreenSave" >> %TEMP%\Screen_save_control.txt 2>&1
reg query "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /f "ScreenSave" >> %TEMP%\Screen_save_group.txt 2>&1

echo ■ 결과 : 수동점검, 화면보호기 활성화 및 대기시간, 암호사용 여부 확인 필요 >> %FILENAME%

echo [화면보호기 설정 값] >> %TEMP%\Screen_save.txt
echo 화면보호기 사용 >> %TEMP%\Screen_save.txt
type %TEMP%\Screen_save_control.txt | find /i "ScreenSaveActive" > nul
if errorlevel 1 (
	echo - ScreenSaveActive 값이 존재하지 않음 >> %TEMP%\Screen_save.txt
) else (
	type %TEMP%\Screen_save_control.txt | find /i "ScreenSaveActive" >> %TEMP%\Screen_save.txt
	echo -----------------------------------------------------------------------  >> %TEMP%\Screen_save.txt
	echo 화면보호기 대기 시간 >> %TEMP%\Screen_save.txt
	type %TEMP%\Screen_save_control.txt | find /i "ScreenSaveTimeOut" > nul
	if errorlevel 1 (
		echo - ScreenSaveTimeOut 값이 존재하지 않음 >> %TEMP%\Screen_save.txt
	) else (
		type %TEMP%\Screen_save_control.txt | find /i "ScreenSaveTimeOut" >> %TEMP%\Screen_save.txt
	)
	echo -----------------------------------------------------------------------  >> %TEMP%\Screen_save.txt
	echo 화면보호기 암호 사용 >> %TEMP%\Screen_save.txt
	type %TEMP%\Screen_save_control.txt | find /i "ScreenSaverIsSecure" > nul
	if errorlevel 1 (
		echo - ScreenSaverIsSecure 값이 존재하지 않음 >> %TEMP%\Screen_save.txt
	) else (
		type %TEMP%\Screen_save_control.txt | find /i "ScreenSaverIsSecure" >> %TEMP%\Screen_save.txt
	)
)

echo. >> %TEMP%\Screen_save.txt
echo [AD 화면보호기 설정 값] >> %TEMP%\Screen_save.txt

type %TEMP%\Screen_save_group.txt | find /i /v "unable to find" > nul
if errorlevel 1 (
	echo - "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" 레지스트리가 존재하지 않음 >> %TEMP%\Screen_save.txt
) else (
	echo 화면보호기 사용 >> %TEMP%\Screen_save.txt
	type %TEMP%\Screen_save_group.txt | find /i "ScreenSaveActive" > nul
	if errorlevel 1 (
		echo - ScreenSaveActive 값이 존재하지 않음 >> %TEMP%\Screen_save.txt
	) else (
		type %TEMP%\Screen_save_group.txt | find /i "ScreenSaveActive" >> %TEMP%\Screen_save.txt
		echo -----------------------------------------------------------------------  >> %TEMP%\Screen_save.txt
		echo 화면보호기 대기 시간 >> %TEMP%\Screen_save.txt
		type %TEMP%\Screen_save_group.txt | find /i "ScreenSaveTimeOut" > nul
		if errorlevel 1 (
			echo - ScreenSaveTimeOut 값이 존재하지 않음 >> %TEMP%\Screen_save.txt
		) else (
			type %TEMP%\Screen_save_group.txt | find /i "ScreenSaveTimeOut" >> %TEMP%\Screen_save.txt
		)
		echo -----------------------------------------------------------------------  >> %TEMP%\Screen_save.txt
		echo 화면보호기 암호 사용 >> %TEMP%\Screen_save.txt
		type %TEMP%\Screen_save_group.txt | find /i "ScreenSaverIsSecure" > nul
		if errorlevel 1 (
			echo - ScreenSaverIsSecure 값이 존재하지 않음 >> %TEMP%\Screen_save.txt
		) else (
			type %TEMP%\Screen_save_group.txt | find /i "ScreenSaverIsSecure" >> %TEMP%\Screen_save.txt
		)
	)
) 

echo. >> %FILENAME%
echo ■ 상세 현항 >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Screen_save.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 주요정보통신기반시설 가이드 기준, 화면보호기 대기 시간: 10분 >> %FILENAME%

echo. >> %FILENAME%
echo ** 설명 :  화면 보호기 설정 확인 ( 실행 -> control desk.cpl,,1 )  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%