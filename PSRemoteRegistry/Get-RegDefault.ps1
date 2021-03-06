function Get-RegDefault
{

	<#
	.SYNOPSIS
	       Retrieves registry default string (REG_SZ) value from local or remote computers.

	.DESCRIPTION
	       Use Get-RegDefault to retrieve registry default string (REG_SZ) value from local or remote computers.
	       
	.PARAMETER ComputerName
	    	An array of computer names. The default is the local computer.

	.PARAMETER Hive
	   	The HKEY to open, from the RegistryHive enumeration. The default is 'LocalMachine'.
	   	Possible values:
	   	
		- ClassesRoot
		- CurrentUser
		- LocalMachine
		- Users
		- PerformanceData
		- CurrentConfig
		- DynData	   	

	.PARAMETER Key
	       The path of the registry key to open. 

	.EXAMPLE
		$Key = "SOFTWARE\MyCompany"
		"SERVER1","SERVER2","SERVER3" | Set-RegDefault -Key $Key -Ping
		
		ComputerName Hive            Key                  Value      Data            Type
		------------ ----            ---                  -----      ----            ----
		SERVER1      LocalMachine    SOFTWARE\MyCompany   (Default)  MyDefaultValue  String		
		SERVER2      LocalMachine    SOFTWARE\MyCompany   (Default)  MyDefaultValue  String		
		SERVER3      LocalMachine    SOFTWARE\MyCompany   (Default)  MyDefaultValue  String		
		
		Description
		-----------
		Gets the reg default value of the SOFTWARE\MyCompany subkey on three remote computers local machine hive (HKLM) .
		Ping each server before setting the value.

	.OUTPUTS
		PSFanatic.Registry.RegistryValue (PSCustomObject)
		
	.NOTES
		Author: Shay Levy
		Blog  : http://blogs.microsoft.co.il/blogs/ScriptFanatic/
		
	.LINK
		http://code.msdn.microsoft.com/PSRemoteRegistry

	.LINK
		Set-RegDefault
		Get-RegValue
	#>
	
	
	[OutputType('PSFanatic.Registry.RegistryValue')]
	[CmdletBinding(DefaultParameterSetName="__AllParameterSets")]
	
	param( 
		[Parameter(
			Position=0,
			ValueFromPipeline=$true,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage="An array of computer names. The default is the local computer."
		)]		
		[Alias("CN","__SERVER","IPAddress")]
		[string[]]$ComputerName="",		
		
		[Parameter(
			Position=1,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage="The HKEY to open, from the RegistryHive enumeration. The default is 'LocalMachine'."
		)]
		[ValidateSet("ClassesRoot","CurrentUser","LocalMachine","Users","PerformanceData","CurrentConfig","DynData")]
		[string]$Hive="LocalMachine",
		
		[Parameter(
			Mandatory=$true,
			Position=2,
			ValueFromPipelineByPropertyName=$true,
			HelpMessage="The path of the subkey to open."
		)]
		[string]$Key,

		[switch]$Ping
	) 
	

	process
	{
	    	
	    	Write-Verbose "Enter process block..."
		
		foreach($c in $ComputerName)
		{	
			try
			{				
				if($c -eq "")
				{
					$c=$env:COMPUTERNAME
					Write-Verbose "Parameter [ComputerName] is not presnet, setting its value to local computer name: [$c]."
					
				}
				
				if($Ping)
				{
					Write-Verbose "Parameter [Ping] is presnet, initiating Ping test"
					
					if( !(Test-Connection -ComputerName $c -Count 1 -Quiet))
					{
						Write-Warning "[$c] doesn't respond to ping."
						return
					}
				}

				
				Write-Verbose "Starting remote registry connection against: [$c]."
				Write-Verbose "Registry Hive is: [$Hive]."
				$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]$Hive,$c)		
				
				Write-Verbose "Open remote subkey: [$Key]."
				$subKey = $reg.OpenSubKey($Key)
				
				if(!$subKey)
				{
					Throw "Key '$Key' doesn't exist."
				}
				
				$pso = New-Object PSObject -Property @{
					ComputerName=$c
					Hive=$Hive
					Value="(Default)"
					Key=$Key
					Data=$subKey.GetValue($null)
					Type=$subKey.GetValueKind($Value)
				}
					
				Write-Verbose "Adding format type name to custom object."
				$pso.PSTypeNames.Clear()
				$pso.PSTypeNames.Add('PSFanatic.Registry.RegistryValue')
				$pso

				Write-Verbose "Closing remote registry connection on: [$c]."
				$subKey.close()
			}
			catch
			{
				Write-Error $_
			}
		} 
		
		Write-Verbose "Exit process block..."
	}
}