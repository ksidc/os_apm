@echo off
set temp2=0
set temp3=0
echo �������������������� W-70. �̺�Ʈ �α� ���� ����	>> %FILENAME%
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
	echo �� ��� : ���, �̺�Ʈ�α� ����� ������ ������         >> %FILENAME%
) else (
	if %temp2% LSS 3 (
		echo �� ��� : ���, �̺�Ʈ�α� �ִ� ũ�Ⱑ 10,240kb �̸����� �����Ǿ� ����         >> %FILENAME%
	) else (
		echo �� ��� : ��ȣ, �̺�Ʈ�α� �ִ� ũ�Ⱑ 10,240kb �̻����� �����Ǿ� ����         >> %FILENAME%
	)
)

echo.	>> %FILENAME%
echo �� �� ��Ȳ		>> %FILENAME%
echo.	>> %FILENAME%
echo [�̺�Ʈ �α� ����� ���� (�������α׷�/�ý���/����)]	>> %FILENAME%
type %TEMP%\eventlog2.txt 	>> %FILENAME%
echo.	>> %FILENAME%
echo [�̺�Ʈ ũ�� ���� (�������α׷�/�ý���/����)]	>> %FILENAME%
type %TEMP%\eventlog.txt 	>> %FILENAME%

echo. >> %FILENAME%
echo ** ���� :  �̺�Ʈ ��� - Windows �α� -  �Ӽ�  :  �ʿ��� ��� �̺�Ʈ ������ ��ȣ  >> %FILENAME%
echo ��� Maxsize 3�� 0x1400000, 0x2800000 �̸� ��ȣ >> %FILENAME%

echo.	>> %FILENAME%
echo.	>> %FILENAME%
echo.	>> %FILENAME%