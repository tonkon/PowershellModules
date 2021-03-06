# PSDiagnostics: Utilities to enable/disable PSRP eventlog entries and set/get log properties
# All the utilities use wevtutil.exe or logman.exe
# 
# Note: Currently we dont log enough data to identify problems related to "Access Denied" errors.
#
# see what logs are available for PSRP and WSMan
eventvwr
ipmo psdiagnostics
gcm -module psdiagnostics
Get-LogProperties Microsoft-Windows-PowerShell/Operational
Get-LogProperties Microsoft-Windows-PowerShell/Analytic
Enable-PSWSManCombinedTrace
$s = nsn
gsn | rsn
Disable-PSWSManCombinedTrace 
dir $pshome\traces
gcm get-winevent -syn
get-winevent -path $pshome\traces\pstrace.etl -oldest
get-winevent -path $pshome\traces\pstrace.etl -oldest | ? { $_.id -eq '32868' }
get-winevent -path $pshome\traces\pstrace.etl -oldest | ? { $_.id -eq '32868' } | % { $_.message }
. C:\temp\Construct-PSRemoteDataObject.ps1
get-winevent -path $pshome\traces\pstrace.etl -oldest  | ? { $_.id -eq '32868' } | % { $idx = $_.message.indexof("Payload Data: 0x"); $str = $_.message.substring($idx + ("Payload Data: 0x".length));Construct-PSRemoteDataObject $str }
del $pshome\traces\pstrace.etl
# lets try another scenario
Enable-PSWSManCombinedTrace
icm . { 1..10 }
Disable-PSWSManCombinedTrace 
get-winevent -path $pshome\traces\pstrace.etl -oldest | ? { $_.providername -match "powershell" } | select id,message
get-winevent -path $pshome\traces\pstrace.etl -oldest  | ? { $_.id -eq '32867' } | % { $idx = $_.message.indexof("Payload Data: 0x"); $str = $_.message.substring($idx + ("Payload Data: 0x".length));Construct-PSRemoteDataObject $str }
del $pshome\traces\pstrace.etl