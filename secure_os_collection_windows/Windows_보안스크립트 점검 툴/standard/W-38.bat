@echo off

echo �������������������� W-38. ȭ�麸ȣ�� ���� >> %FILENAME%
echo. >> %FILENAME%

:: ȭ�麸ȣ�� ���� Ȯ��
reg query "HKCU\Control Panel\Desktop" /f "ScreenSave" >> %TEMP%\Screen_save_control.txt 2>&1
reg query "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /f "ScreenSave" >> %TEMP%\Screen_save_group.txt 2>&1

echo �� ��� : ��������, ȭ�麸ȣ�� Ȱ��ȭ �� ���ð�, ��ȣ��� ���� Ȯ�� �ʿ� >> %FILENAME%

echo [ȭ�麸ȣ�� ���� ��] >> %TEMP%\Screen_save.txt
echo ȭ�麸ȣ�� ��� >> %TEMP%\Screen_save.txt
type %TEMP%\Screen_save_control.txt | find /i "ScreenSaveActive" > nul
if errorlevel 1 (
	echo - ScreenSaveActive ���� �������� ���� >> %TEMP%\Screen_save.txt
) else (
	type %TEMP%\Screen_save_control.txt | find /i "ScreenSaveActive" >> %TEMP%\Screen_save.txt
	echo -----------------------------------------------------------------------  >> %TEMP%\Screen_save.txt
	echo ȭ�麸ȣ�� ��� �ð� >> %TEMP%\Screen_save.txt
	type %TEMP%\Screen_save_control.txt | find /i "ScreenSaveTimeOut" > nul
	if errorlevel 1 (
		echo - ScreenSaveTimeOut ���� �������� ���� >> %TEMP%\Screen_save.txt
	) else (
		type %TEMP%\Screen_save_control.txt | find /i "ScreenSaveTimeOut" >> %TEMP%\Screen_save.txt
	)
	echo -----------------------------------------------------------------------  >> %TEMP%\Screen_save.txt
	echo ȭ�麸ȣ�� ��ȣ ��� >> %TEMP%\Screen_save.txt
	type %TEMP%\Screen_save_control.txt | find /i "ScreenSaverIsSecure" > nul
	if errorlevel 1 (
		echo - ScreenSaverIsSecure ���� �������� ���� >> %TEMP%\Screen_save.txt
	) else (
		type %TEMP%\Screen_save_control.txt | find /i "ScreenSaverIsSecure" >> %TEMP%\Screen_save.txt
	)
)

echo. >> %TEMP%\Screen_save.txt
echo [AD ȭ�麸ȣ�� ���� ��] >> %TEMP%\Screen_save.txt

type %TEMP%\Screen_save_group.txt | find /i /v "unable to find" > nul
if errorlevel 1 (
	echo - "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" ������Ʈ���� �������� ���� >> %TEMP%\Screen_save.txt
) else (
	echo ȭ�麸ȣ�� ��� >> %TEMP%\Screen_save.txt
	type %TEMP%\Screen_save_group.txt | find /i "ScreenSaveActive" > nul
	if errorlevel 1 (
		echo - ScreenSaveActive ���� �������� ���� >> %TEMP%\Screen_save.txt
	) else (
		type %TEMP%\Screen_save_group.txt | find /i "ScreenSaveActive" >> %TEMP%\Screen_save.txt
		echo -----------------------------------------------------------------------  >> %TEMP%\Screen_save.txt
		echo ȭ�麸ȣ�� ��� �ð� >> %TEMP%\Screen_save.txt
		type %TEMP%\Screen_save_group.txt | find /i "ScreenSaveTimeOut" > nul
		if errorlevel 1 (
			echo - ScreenSaveTimeOut ���� �������� ���� >> %TEMP%\Screen_save.txt
		) else (
			type %TEMP%\Screen_save_group.txt | find /i "ScreenSaveTimeOut" >> %TEMP%\Screen_save.txt
		)
		echo -----------------------------------------------------------------------  >> %TEMP%\Screen_save.txt
		echo ȭ�麸ȣ�� ��ȣ ��� >> %TEMP%\Screen_save.txt
		type %TEMP%\Screen_save_group.txt | find /i "ScreenSaverIsSecure" > nul
		if errorlevel 1 (
			echo - ScreenSaverIsSecure ���� �������� ���� >> %TEMP%\Screen_save.txt
		) else (
			type %TEMP%\Screen_save_group.txt | find /i "ScreenSaverIsSecure" >> %TEMP%\Screen_save.txt
		)
	)
) 

echo. >> %FILENAME%
echo �� �� ���� >> %FILENAME%
echo. >> %FILENAME%
type %TEMP%\Screen_save.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� �ֿ�������ű�ݽü� ���̵� ����, ȭ�麸ȣ�� ��� �ð�: 10�� >> %FILENAME%

echo. >> %FILENAME%
echo ** ���� :  ȭ�� ��ȣ�� ���� Ȯ�� ( ���� -> control desk.cpl,,1 )  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%