@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-77. LAN Manager 인증 수준 >> %FILENAME%
echo. >> %FILENAME%

type Config\%COMPUTERNAME%_Security_Policy.txt | find /i "LmCompatibilityLevel" > nul
if errorlevel 1 (
	echo ■ 결과 : 양호, LAN Manager 인증 수준이 정의되지 않아 기본값인 "NTLMv2 응답만 보냄"으로 적용됨 >> %FILENAME%
	echo. 	>> %FILENAME%
	echo ■ 상세 현황			>> %FILENAME%
	echo. 	>> %FILENAME%
	echo - LmCompatibilityLevel 레지스트리 값이 존재하지 않음 	>> %FILENAME%
	goto W-77_end
)
type Config\%COMPUTERNAME%_Security_Policy.txt | findstr /I "LmCompatibilityLevel" | Tools\awk.exe -F\ "{print $6}" > %TEMP%\NTLMver.txt
for /F "tokens=2 delims=," %%a in (%TEMP%\NTLMver.txt) do set COM_LV=%%a
if %COM_LV% GEQ 3 (
	echo ■ 결과 : 양호, LAN Manager 인증 수준이 NTLMv2 응답만 보내도록 설정되어 있음	>> %FILENAME%
) else (
	echo ■ 결과 : 취약, LAN Manager 인증 수준이 NT 또는 NTLM 응답만 보내도록 설정되어 있음	>> %FILENAME%
)
echo. 	>> %FILENAME%
echo ■ 상세 현황			>> %FILENAME%
echo. 	>> %FILENAME%
type %TEMP%\NTLMver.txt	>> %FILENAME%
echo. 	>> %FILENAME%
echo ※ 참고 >> %FILENAME%
echo LmCompatibilityLevel 4,0 : LM 및 NTLM 응답 보내기 >> %FILENAME%
echo LmCompatibilityLevel 4,1 : LM 및 NTLM 보내기 - 협상되면 NTLMv2 세션 보안 사용 >> %FILENAME%
echo LmCompatibilityLevel 4,2 : NTLM 응답만 보내기	>> %FILENAME%
echo LmCompatibilityLevel 4,3 : NTLMv2 응답만 보내기	>> %FILENAME%
echo LmCompatibilityLevel 4,4 : NTLMv2 응답만 보내기 및 LM 거부	>> %FILENAME%
echo LmCompatibilityLevel 4,5 : NTLMv2 응답만 보냅니다. LM 및 NTLM은 거부합니다. >> %FILENAME%

:W-77_end
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%
echo. 	>> %FILENAME%