@echo off

echo �������������������� W-21. IIS �̻�� ��ũ��Ʈ ���� ���� >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%i IN (%TEMP%\IIS_web_name.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Mapping_handler.txt
	echo ����Ʈ�� : %%i >> %TEMP%\Mapping_handler.txt
	%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" > nul
	if errorlevel 1 (
		echo - ����� ������ �������� ���� >> %TEMP%\Mapping_handler.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" >> %TEMP%\Mapping_handler.txt
	)
)

type %TEMP%\Mapping_handler.txt | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" > nul
if errorlevel 1 (
	echo �� ��� : ��ȣ, ����� ������ �������� ���� >> %FILENAME%
) else (
	echo �� ��� : ���, ����� ������ ������ >> %FILENAME%
)

echo. >> %FILENAME%
echo �� �� ��Ȳ >> %FILENAME%
echo. >> %FILENAME%

echo [�⺻ ����] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config | find /i "scriptprocessor" | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" >> %FILENAME%
if errorlevel 1 (
	echo - ����� ������ �������� ���� >> %FILENAME%
) else (
	%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" >> %FILENAME%
)

echo. >> %FILENAME%
echo [����Ʈ�� ����] >> %FILENAME%
type %TEMP%\Mapping_handler.txt >> %FILENAME%

echo. >> %FILENAME%
echo �� ����� ���� : .htr .idc .stm .shtm .shtml .printer .htw .ida .idq >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%