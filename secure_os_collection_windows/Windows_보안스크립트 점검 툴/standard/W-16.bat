@echo off

echo �������������������� W-16. IIS ��ũ ��� ���� >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%j IN (%TEMP%\IIS_root_path.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Link_files.txt
	echo Ȩ ���丮 ��� : %%j >> %TEMP%\Link_files.txt
	dir /s /b %%j | find /i ".lnk" > nul
	if errorlevel 1 (
		echo - ��ũ ������ �������� ���� >> %TEMP%\Link_files.txt
	) else (
		dir /s /b %%j | find /i ".lnk" >> %TEMP%\Link_files.txt
	)
	echo. >> %TEMP%\Link_files.txt
)

type %TEMP%\Link_files.txt | find /i ".lnk" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, �� ����Ʈ Ȩ ���丮�� ��ũ ������ �������� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, ��ũ ������ �����ϴ� �� ����Ʈ Ȩ ���丮�� Ȯ�ε� >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%
echo [����Ʈ ���] >> %FILENAME%
type %CONFIG%IIS_WebList.txt >> %FILENAME%
echo. >> %FILENAME%
echo [Ȩ ���丮 ����] >> %FILENAME%
FOR /f "delims=" %%k IN (%TEMP%\IIS_web_name.txt) DO (
	%systemroot%\System32\inetsrv\appcmd list site %%k /config | findstr /i "name protocol physicalpath" >> %FILENAME%
)
echo. >> %FILENAME%
echo [����Ʈ�� ���ʿ� ���� Ȯ��] >> %FILENAME%
type %TEMP%\Link_files.txt >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%