@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-21. IIS 미사용 스크립트 매핑 제거 >> %FILENAME%
echo. >> %FILENAME%

FOR /f "delims=" %%i IN (%TEMP%\IIS_web_name.txt) DO (
	echo -----------------------------------------------------------------------  >> %TEMP%\Mapping_handler.txt
	echo 사이트명 : %%i >> %TEMP%\Mapping_handler.txt
	%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" > nul
	if errorlevel 1 (
		echo - 취약한 매핑이 존재하지 않음 >> %TEMP%\Mapping_handler.txt
	) else (
		%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" >> %TEMP%\Mapping_handler.txt
	)
)

type %TEMP%\Mapping_handler.txt | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, 취약한 매핑이 존재하지 않음 >> %FILENAME%
) else (
	echo ■ 결과 : 취약, 취약한 매핑이 존재함 >> %FILENAME%
)

echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%

echo [기본 설정] >> %FILENAME%
%systemroot%\System32\inetsrv\appcmd list config | find /i "scriptprocessor" | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" >> %FILENAME%
if errorlevel 1 (
	echo - 취약한 매핑이 존재하지 않음 >> %FILENAME%
) else (
	%systemroot%\System32\inetsrv\appcmd list config %%i | find /i "scriptprocessor" | findstr /i "\.htr \.idc \.stm \.shtm \.shtml \.printer \.htw \.ida \.idq" >> %FILENAME%
)

echo. >> %FILENAME%
echo [사이트별 설정] >> %FILENAME%
type %TEMP%\Mapping_handler.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 취약한 매핑 : .htr .idc .stm .shtm .shtml .printer .htw .ida .idq >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%