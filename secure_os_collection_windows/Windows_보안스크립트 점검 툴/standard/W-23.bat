@echo off

echo �������������������� W-23. IIS WebDAV ��Ȱ��ȭ >> %FILENAME%
echo. >> %FILENAME%

%systemroot%\System32\inetsrv\appcmd list config -section:isapiCgiRestriction | find /i "WebDAV" >> %TEMP%\Web_dav.txt

for %%f in (%TEMP%\Web_dav.txt) do (
	if %%~zf EQU 0 (
		echo �� ��� : ��ȣ, WebDAV�� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
		echo. >> %FILENAME%
		echo �� �� ��Ȳ >> %FILENAME%
		echo. >> %FILENAME%
		echo - WebDAV������ ��ġ���� ���� >> %FILENAME%
	) else (
		type %TEMP%\Web_dav.txt | find /i "false" > nul
		if errorlevel 1 (
			echo �� ��� : ���, WebDAV�� Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Web_dav.txt >> %FILENAME%
		) else (
			echo �� ��� : ��ȣ, WebDAV�� ��Ȱ��ȭ�Ǿ� ���� >> %FILENAME%
			echo. >> %FILENAME%
			echo �� �� ��Ȳ >> %FILENAME%
			echo. >> %FILENAME%
			type %TEMP%\Web_dav.txt >> %FILENAME%
		)
	)
)

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%