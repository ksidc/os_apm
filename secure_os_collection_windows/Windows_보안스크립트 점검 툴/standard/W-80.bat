@echo off

echo �������������������� W-80. ��ǻ�� ���� ��ȣ �ִ� ��� �Ⱓ >> %FILENAME%
echo. >> %FILENAME%
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /i "\disablepasswordchange" > %TEMP%\Disable_pwchange.txt
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /i "\MaximumPasswordAge" > %TEMP%\Maximum_pwage.txt

for /F "tokens=2 delims=," %%a in (%TEMP%\Disable_pwchange.txt) do set PW_CH=%%a
for /F "tokens=2 delims=," %%b in (%TEMP%\Maximum_pwage.txt) do set PW_AGE=%%b

if "%PW_CH%"=="1" (
	echo �� ��� : ���, ��ǻ�� ���� ��ȣ ���� ��� �� �� ��å�� ������� �����Ǿ� �־� ���� ��ȣ �ִ� ��� �Ⱓ�� ������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo [��ǻ�� ���� ��ȣ ���� ��� �� ��] >> %FILENAME%
	type %TEMP%\Disable_pwchange.txt | Tools\awk.exe -F\ "{print $7}" >> %FILENAME%
) else (
	if %PW_AGE% GEQ 1 if %PW_AGE% LEQ 90 echo �� ��� : ��ȣ, ��ǻ�� ���� ��ȣ �ִ� ���Ⱓ�� 90�� ���Ϸ� �����Ǿ� ���� >> %FILENAME%
	if %PW_AGE% GTR 90 echo �� ��� : ���, ��ǻ�� ���� ��ȣ �ִ� ��� �Ⱓ�� 90���� �ʰ��� ������ �����Ǿ� ���� >> %FILENAME%
	if "%PW_AGE%"=="0" echo �� ��� : ���, ��ǻ�� ���� ��ȣ �ִ� ��� �Ⱓ�� 0�Ϸ� �����Ǿ� ��ȣ�� ������� ���� >> %FILENAME%
	echo. >> %FILENAME%
	echo �� �� ��Ȳ >> %FILENAME%
	echo. >> %FILENAME%
	echo [��ǻ�� ���� ��ȣ ���� ��� �� ��] >> %FILENAME%
	type %TEMP%\Disable_pwchange.txt | Tools\awk.exe -F\ "{print $7}" >> %FILENAME%
	echo. >> %FILENAME%
	echo [��ǻ�� ���� ��ȣ �ִ� ��� �Ⱓ] >> %FILENAME%
	type %TEMP%\Maximum_pwage.txt | Tools\awk.exe -F\ "{print $7}" >> %FILENAME%	
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%