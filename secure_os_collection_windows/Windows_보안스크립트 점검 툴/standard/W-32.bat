@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-32. 최신 HOT FIX 적용 >> %FILENAME%
echo. >> %FILENAME%

wmic qfe get HotFixID,InstalledOn,Description >> %CONFIG%HotFix.txt 2>&1

echo ■ 결과 : 수동점검, Hot Fix 이력 확인 필요 >> %FILENAME%
echo. >> %FILENAME%

echo ■ 상세 현황 >> %FILENAME%
echo. >> %FILENAME%
type %CONFIG%HotFix.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ Hot Fix 업데이트 일자는 다음 사이트를 참고 https://www.catalog.update.microsoft.com/Home.aspx >> %FILENAME%
echo    점검 결과 내 Hot Fix 상세 정보는 %CONFIG%HotFix.txt 또는 %CONFIG%System_Info.txt 파일 참고 >> %FILENAME%

echo. >> %FILENAME%
echo ** 설명 :  최신 업데이트 여부 확인  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%