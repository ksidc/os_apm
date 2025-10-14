@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-23. IIS WebDAV 비활성화 >> %FILENAME%
echo. >> %FILENAME%

%systemroot%\System32\inetsrv\appcmd list config -section:isapiCgiRestriction | find /i "WebDAV" >> %TEMP%\Web_dav.txt

for %%f in (%TEMP%\Web_dav.txt) do (
	if %%~zf EQU 0 (
		echo ■ 결과 : 양호, WebDAV가 비활성화되어 있음 >> %FILENAME%
		echo. >> %FILENAME%
		echo ■ 상세 현황 >> %FILENAME%
		echo. >> %FILENAME%
		echo - WebDAV역할을 설치하지 않음 >> %FILENAME%
	) else (
		type %TEMP%\Web_dav.txt | find /i "false" > nul
		if errorlevel 1 (
			echo ■ 결과 : 취약, WebDAV가 활성화되어 있음 >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Web_dav.txt >> %FILENAME%
		) else (
			echo ■ 결과 : 양호, WebDAV가 비활성화되어 있음 >> %FILENAME%
			echo. >> %FILENAME%
			echo ■ 상세 현황 >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Web_dav.txt >> %FILENAME%
		)
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%