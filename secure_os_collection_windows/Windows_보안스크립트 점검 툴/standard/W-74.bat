@echo off

echo �������������������� W-74. ���� ������ �ߴ��ϱ� ���� �ʿ��� ���޽ð� >> %FILENAME%
echo. >> %FILENAME%
reg query "HKLM\System\CurrentControlSet\Services\LanManServer\Parameters" >> %CONFIG%Session_Reg.txt 2>&1
type Config\%COMPUTERNAME%_Session_Reg.txt | findstr /i "EnableForcedLogoff" > %TEMP%\Session_log.txt
type Config\%COMPUTERNAME%_Session_Reg.txt | findstr /i "AutoDisconnect" > %TEMP%\Session_dis.txt
type %TEMP%\Session_log.txt | findstr /i "EnableForcedLogoff" > nul
if errorlevel 1 (
	echo �� ��� : ���, �α׿� �ð��� ����Ǹ� Ŭ���̾�Ʈ ���� ���� ��å�� �����Ǿ� ���� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo EnableForcedLogoff ������Ʈ�� ���� �������� ���� >> %FILENAME%
	goto W-74_END
) else (
	type %TEMP%\Session_log.txt | findstr /i "0x1" > nul
	if errorlevel 1 (
		echo �� ��� : ���, �α׿� �ð��� ����Ǹ� Ŭ���̾�Ʈ ���� ���� ��å�� ��� �� �� ���� �����Ǿ� ���� >> %FILENAME%
		echo. >> %FILENAME%
		echo �� �� ��Ȳ >> %FILENAME%
		type %TEMP%\Session_log.txt >> %FILENAME%
		goto W-74_END
	) else (
		echo [�α׿� �ð��� ����Ǹ� Ŭ���̾�Ʈ ���� ����] > %TEMP%\Session_policy.txt
		type %TEMP%\Session_log.txt >> %TEMP%\Session_policy.txt
		echo. >> %TEMP%\Session_policy.txt
		echo [���� ������ �ߴ��ϱ� ���� �ʿ��� ���� �ð�] >> %TEMP%\Session_policy.txt	
		type %TEMP%\Session_dis.txt | findstr /i "AutoDisconnect" > nul
		if errorlevel 1 (
			echo �� ��� : ��ȣ, ���� ������ �ߴ��ϱ� ���� �ʿ��� ���� �ð� ��å�� �����Ǿ� ���� ���� >> %FILENAME%
			echo AutoDisconnect�� ���ǵǾ� ���� �����Ƿ� Default ���� 15������ ���� >> %TEMP%\Session_policy.txt
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			type %TEMP%\Session_policy.txt >> %FILENAME%
			goto W-74_END
		) else (
			type %TEMP%\Session_dis.txt >> %TEMP%\Session_policy.txt
			goto W-74_Check
		)
	)
)

:W-74_Check
For /F "tokens=3" %%e in (Temp\Session_dis.txt) Do set A_TEMP=%%e
set /a B_TEMP=%A_TEMP%

if %A_TEMP% GTR 15 (
	echo �� ��� : ���, ���� ������ �ߴ��ϱ� ���� �ʿ��� ���� �ð� ��å�� %B_TEMP%������ �����Ǿ� ���� >> %FILENAME%	
) else (
	echo �� ��� : ��ȣ, ���� ������ �ߴ��ϱ� ���� �ʿ��� ���� �ð� ��å�� 15�� ���Ϸ� �����Ǿ� ���� >> %FILENAME%
)
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
type %TEMP%\Session_policy.txt >> %FILENAME%

:W-74_END
echo.  	>> %FILENAME%  
echo.  	>> %FILENAME%
echo.  	>> %FILENAME%