@echo off

echo ▶▶▶▶▶▶▶▶▶▶ W-44. 이동식 미디어 포맷 및 꺼내기 허용 >> %FILENAME%
echo. >> %FILENAME%

type %CONFIG%Security_Policy.txt | find /i "AllocateDASD" >> %TEMP%\Allocate_dasd.txt
echo ■ 결과 : 수동점검, '이동식 미디어 포맷 및 꺼내기 허용' 정책 설정 값 확인 >> %FILENAME%
echo. >> %FILENAME%
echo ■ 상세 현황 >> %FILENAME%
type %TEMP%\Allocate_dasd.txt >> %FILENAME%

echo. >> %FILENAME%
echo ※ 1,"0": Administrators / 1,"1": Administrators 및 Power Users / 1,"2": Administrators 및 Interactive Users >> %FILENAME%
echo 만약, 결과가 없을 경우 해당 정책이 정의되지 않아 default로 Administrators만 허용됨 >> %FILENAME%

echo. >> %FILENAME%
echo ** 설명 :  결과가 없으면 양호  >> %FILENAME%

echo. >> %FILENAME%
echo. >> %FILENAME%
echo. >> %FILENAME%