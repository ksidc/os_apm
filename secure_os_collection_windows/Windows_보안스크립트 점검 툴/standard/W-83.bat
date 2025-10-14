echo --------------------------------���� ����--------------------------------------------------- >> "%FILENAME%"
echo. >> "%FILENAME%"

:: ================================================
:: 31. Windows Update �ڵ� ������Ʈ ���� Ȯ��
:: ================================================
echo ��������������������  Windows Update �ڵ� ������Ʈ ���� >> "%FILENAME%"
sc query wuauserv | find "STATE" >> "%FILENAME%"
sc qc wuauserv | find "START_TYPE" >> "%FILENAME%"
sc query WaaSMedicSvc | find "STATE" >> "%FILENAME%"
sc qc WaaSMedicSvc | find "START_TYPE" >> "%FILENAME%"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate >> "%FILENAME%" 2>&1
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** ���� :  >> "%FILENAME%"
echo - wuauserv, WaaSMedicSvc: STATE = STOPPED, START_TYPE = DISABLED �̾�� ����. >> "%FILENAME%"
echo - NoAutoUpdate = 0x1, AUOptions = 0x1 �̸� �ڵ� ������Ʈ ���� ��Ȱ��ȭ. >> "%FILENAME%"
echo. >> "%FILENAME%"

:: ================================================
:: 32. ���� Ȯ���� ���� ���� Ȯ��
:: ================================================
echo �������������������� ���� Ȯ���� ���� ���� >> "%FILENAME%"
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** ���� :  >> "%FILENAME%"
echo - HideFileExt = 0x0 �̸� "Ȯ���� ǥ��" Ȱ��ȭ�� ����. >> "%FILENAME%"
echo. >> "%FILENAME%"

:: ================================================
:: 33. �̺�Ʈ �α� �ִ� ũ�� ���� Ȯ��
:: ================================================
echo �������������������� �̺�Ʈ �α� �ִ� ũ�� ���� >> "%FILENAME%"
echo. >> "%FILENAME%"
echo ** ���� :  >> "%FILENAME%"
echo - �̺�Ʈ ��� - Windows �α� - �������α׷�, �ý���, ����  - �Ӽ� ���� >> "%FILENAME%"
echo �������α׷�, �ý��� : 20480, ���� : 40960 Ȯ�� >> "%FILENAME%"
echo. >> "%FILENAME%"



:: ================================================
:: 35. WDigest ���� ��Ȱ��ȭ Ȯ��
:: ================================================
echo �������������������� WDigest ���� ��Ȱ��ȭ >> "%FILENAME%"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" /v UseLogonCredential >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** ���� :  >> "%FILENAME%"
echo - UseLogonCredential = 0x0 �̸� ��Ȱ��ȭ(����). 0x1 �̸� ��� ����. >> "%FILENAME%"
echo. >> "%FILENAME%"


:: ================================================
:: 36. ���� ����ũ�� ��Ʈ �� ��ȭ�� ��� Ȯ��
:: ================================================
echo �������������������� ���� ����ũ�� ��Ʈ �� ��ȭ�� ��Ģ >> "%FILENAME%"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber >> "%FILENAME%" 2>&1
netsh advfirewall firewall show rule name="Allow RDP Port 48321" >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** ���� :  >> "%FILENAME%"
echo - PortNumber = 48321 �̸� ��Ʈ ���� ���� ����. >> "%FILENAME%"
echo - ��ȭ�� ��Ģ "Allow RDP Port 48321" �� ENABLED �̸� ����. >> "%FILENAME%"
echo. >> "%FILENAME%"

:: ================================================
:: 37. TCP/RDP Ʃ�� ���� Ȯ��
:: ================================================
echo ��������������������TCP/RDP ���� Ȯ�� >> "%FILENAME%"
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpTimedWaitDelay >> "%FILENAME%" 2>&1
reg query "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v MaxUserPort >> "%FILENAME%" 2>&1
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections >> "%FILENAME%" 2>&1
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fSingleSessionPerUser >> "%FILENAME%" 2>&1
reg query "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MaxInstanceCount >> "%FILENAME%" 2>&1
echo. >> "%FILENAME%"
echo ** ���� :  >> "%FILENAME%"
echo - TcpTimedWaitDelay = 0x1e, MaxUserPort = 0xfffe �� ����. >> "%FILENAME%"
echo - fDenyTSConnections = 0 ( RDP ���), fSingleSessionPerUser = 0 (��Ƽ ���� ���). >> "%FILENAME%"
echo - MaxInstanceCount = 2 (���� ���� �ִ� 2��) �̸� ����. >> "%FILENAME%"
echo. >> "%FILENAME%"
