@echo off

echo �������������������� W-02. Guest ���� ��Ȱ��ȭ >> %FILENAME%
echo. >> %FILENAME%

net user GST > %TEMP%\GST.txt
for %%f in (%TEMP%\GST.txt) do (
	if %%~zf EQU 0 goto guest
)

:GST
net user guest > %TEMP%\guest.txt
net user GST > %TEMP%\GST.txt
for %%i in (%TEMP%\guest.txt) do (
	if %%~zi EQU 0 (
		type %TEMP%\GST.txt | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			echo �� ��� : ���, guest������ ��Ȱ��ȭ�ϰ� ������, GST������ Ȱ��ȭ�ϰ� ����*1 >> %FILENAME%
		) else (
			echo �� ��� : ��ȣ, guest ������ ��Ȱ��ȭ�ϰ� ����*2 >> %FILENAME%
		)
	) else (
		type %TEMP%\guest.txt | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			type %TEMP%\GST.txt | find /i "Account active" | find /i "No" > nul
			if errorlevel 1 (
				echo �� ��� : ���, guest ������ Ȱ��ȭ�ϰ� ����*3 >> %FILENAME%
			) else (
				echo �� ��� : ���, GST������ ��Ȱ��ȭ�ϰ� ������, guest������ Ȱ��ȭ�ϰ� ����*4	>> %FILENAME%
			)
		) else (
			type %TEMP%\GST.txt | find /i "Account active" | find /i "No" > nul
			if errorlevel 1 (
				echo �� ��� : ���, guest������ ��Ȱ��ȭ�ϰ� ������, GST������ Ȱ��ȭ�ϰ� ����*5 >> %FILENAME%
			) else (
				echo �� ��� : ��ȣ, guest ������ ��Ȱ��ȭ�ϰ� ����*6 >> %FILENAME%
			)
		)
	)
)
goto result

:guest
net user guest > %TEMP%\guest.txt
type %TEMP%\guest.txt | find /i "Account active" | find /i "No" > nul
if errorlevel 1 (
	echo �� ��� : ���, guest ������ Ȱ��ȭ�ϰ� ����*7 >> %FILENAME%
) else (
	echo �� ��� : ��ȣ, guest ������ ��Ȱ��ȭ�ϰ� ����*8 >> %FILENAME%
)

:result
echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [Guest ����] >> %FILENAME%
for %%a in (%TEMP%\guest.txt) do (
	if %%~za EQU 0 (
		echo - Guest������ �������� ����	>> %FILENAME%
	) else (
		type %TEMP%\guest.txt | find /i "User name" >> %FILENAME%
		type %TEMP%\guest.txt | find /i "Account active" >> %FILENAME%
	)
)
echo. >> %FILENAME%
echo [GST ����] >> %FILENAME%
for %%b in (%TEMP%\GST.txt) do (
	if %%~zb EQU 0 (
		echo - GST������ �������� ����	>> %FILENAME%
	) else (
		type %TEMP%\GST.txt | find /i "User name" >> %FILENAME%
		type %TEMP%\GST.txt | find /i "Account active" >> %FILENAME%
	)
)
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%