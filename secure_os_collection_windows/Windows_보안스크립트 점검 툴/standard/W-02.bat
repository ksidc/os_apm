@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-02. Guest 계정 비활성화 >> %FILENAME%
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
			echo ■ 결과 : 취약, guest계정을 비활성화하고 있으나, GST계정을 활성화하고 있음*1 >> %FILENAME%
		) else (
			echo ■ 결과 : 양호, guest 계정을 비활성화하고 있음*2 >> %FILENAME%
		)
	) else (
		type %TEMP%\guest.txt | find /i "Account active" | find /i "No" > nul
		if errorlevel 1 (
			type %TEMP%\GST.txt | find /i "Account active" | find /i "No" > nul
			if errorlevel 1 (
				echo ■ 결과 : 취약, guest 계정을 활성화하고 있음*3 >> %FILENAME%
			) else (
				echo ■ 결과 : 취약, GST계정을 비활성화하고 있으나, guest계정을 활성화하고 있음*4	>> %FILENAME%
			)
		) else (
			type %TEMP%\GST.txt | find /i "Account active" | find /i "No" > nul
			if errorlevel 1 (
				echo ■ 결과 : 취약, guest계정을 비활성화하고 있으나, GST계정을 활성화하고 있음*5 >> %FILENAME%
			) else (
				echo ■ 결과 : 양호, guest 계정을 비활성화하고 있음*6 >> %FILENAME%
			)
		)
	)
)
goto result

:guest
net user guest > %TEMP%\guest.txt
type %TEMP%\guest.txt | find /i "Account active" | find /i "No" > nul
if errorlevel 1 (
	echo ■ 결과 : 취약, guest 계정을 활성화하고 있음*7 >> %FILENAME%
) else (
	echo ■ 결과 : 양호, guest 계정을 비활성화하고 있음*8 >> %FILENAME%
)

:result
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
echo [Guest 계정] >> %FILENAME%
for %%a in (%TEMP%\guest.txt) do (
	if %%~za EQU 0 (
		echo - Guest계정이 존재하지 않음	>> %FILENAME%
	) else (
		type %TEMP%\guest.txt | find /i "User name" >> %FILENAME%
		type %TEMP%\guest.txt | find /i "Account active" >> %FILENAME%
	)
)
echo. >> %FILENAME%
echo [GST 계정] >> %FILENAME%
for %%b in (%TEMP%\GST.txt) do (
	if %%~zb EQU 0 (
		echo - GST계정이 존재하지 않음	>> %FILENAME%
	) else (
		type %TEMP%\GST.txt | find /i "User name" >> %FILENAME%
		type %TEMP%\GST.txt | find /i "Account active" >> %FILENAME%
	)
)
echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%