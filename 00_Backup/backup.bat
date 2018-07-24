@echo off
set Backup_folder=F:\Jedox\jedox_backup
set Jedox_suite_folder=C:\Program Files (x86)\Jedox\Jedox Suite
set Jedox_suite_log_folder=F:\Jedox\Jedox Suite
set Jedox_suite_olap_folder=E:\Jedox\Jedox Suite

set Current_backup_folder=%Backup_folder%\backupset0
set Jedox_data_folder=%Jedox_suite_olap_folder%\olap\data
set Jedox_storage_folder=%Jedox_suite_log_folder%\storage
set Jedox_etlserver_data_folder=%Jedox_suite_log_folder%\tomcat\webapps\etlserver\data

if /I "%1" EQU "StopService" goto StopService
if /I "%1" EQU "StartService" goto StartService
if /I "%1" EQU "MaintainBackups" goto MaintainBackups
if /I "%1" EQU "DoBackup" goto DoBackup

:Main
call %0 StopService JedoxSuiteHttpdService
call %0 StopService JedoxSuiteCoreService
call %0 StopService JedoxSuiteTomcatService
call %0 StopService JedoxSuiteMolapService
call %0 MaintainBackups
call %0 DoBackup
call %0 StartService JedoxSuiteMolapService
call %0 StartService JedoxSuiteTomcatService
call %0 StartService JedoxSuiteCoreService
call %0 StartService JedoxSuiteHttpdService
goto :EOF

:StopService
@echo Stopping %2
set /a Max_wait_time=600
net stop %2
:Waiting_stopped
for /F "tokens=3 delims=: " %%H in ('sc query "%2" ^| findstr "        STATE"') do (
if %Max_wait_time% LEQ 0 GOTO :StopTimeout

if /I "%%H" NEQ "STOPPED" (
ping localhost -n 6 > nul
set /a Max_wait_time = Max_wait_time – 5
goto Waiting_stopped
)
)
goto :EOF

:StopTimeout
@echo Timeout waiting for service %2 to stop
exit

:StartService
@echo Starting %2
set /a Max_wait_time=600
net start %2
:Waiting_started
for /F "tokens=3 delims=: " %%H in ('sc query "%2" ^| findstr "        STATE"') do (
if %Max_wait_time% LEQ 0 GOTO :StartTimeout

if /I "%%H" NEQ "RUNNING" (
ping localhost -n 6 > nul
set /a Max_wait_time = Max_wait_time – 5
goto Waiting_started
)
)
goto :EOF

:StartTimeout
@echo Timeout waiting for service %2 to start
exit

:MaintainBackups
rmdir /S /Q %Backup_folder%\backupset14
ren %Backup_folder%\backupset6 backupset14
ren %Backup_folder%\backupset6 backupset13
ren %Backup_folder%\backupset6 backupset12
ren %Backup_folder%\backupset6 backupset11
ren %Backup_folder%\backupset6 backupset10
ren %Backup_folder%\backupset6 backupset9
ren %Backup_folder%\backupset6 backupset8
ren %Backup_folder%\backupset6 backupset7
ren %Backup_folder%\backupset5 backupset6
ren %Backup_folder%\backupset4 backupset5
ren %Backup_folder%\backupset3 backupset4
ren %Backup_folder%\backupset2 backupset3
ren %Backup_folder%\backupset1 backupset2
ren %Backup_folder%\backupset0 backupset1
mkdir %Backup_folder%\backupset0
goto :EOF

:DoBackup
del "%Current_backup_folder%\*.*" /Q
mkdir %Backup_folder%\backupset0\olap_data
mkdir %Backup_folder%\backupset0\storage
mkdir %Backup_folder%\backupset0\httpd_conf
mkdir %Backup_folder%\backupset0\httpd_app_etc
mkdir %Backup_folder%\backupset0\core
mkdir %Backup_folder%\backupset0\etlserver_data
mkdir %Backup_folder%\backupset0\docroot
xcopy "%Jedox_data_folder%\*.*" "%Current_backup_folder%"\olap_data /Y /E
xcopy "%Jedox_storage_folder%\*.*" "%Current_backup_folder%"\storage /Y /E
xcopy "%Jedox_suite_folder%\httpd\conf\httpd.conf" "%Current_backup_folder%"\httpd_conf /Y
xcopy "%Jedox_suite_folder%\core\palo_config.xml" "%Current_backup_folder%"\core /Y
xcopy "%Jedox_suite_folder%\httpd\app\etc\config.php" "%Current_backup_folder%"\httpd_app_etc /Y
xcopy "%Jedox_etlserver_data_folder%\*.*" "%Current_backup_folder%"\etlserver_data /Y /E
xcopy "%Jedox_suite_folder%\httpd\app\docroot\*.*" "%Current_backup_folder%"\docroot /Y /E

rem activate next line to remove *.archived files
rem del /s "%Jedox_data_folder%\*.archived"
