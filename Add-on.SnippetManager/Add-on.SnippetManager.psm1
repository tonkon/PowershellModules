#######################################################################################################################
# File:             Add-on.SnippetManager.psm1                                                                        #
# Author:           Denniver Reining                                                                                  #
# Publisher:        www.bitspace.de                                                                                   #
# Copyright:        © 2010 www.bitspace.de. All rights reserved.                                                      #
# Usage:            To load this module in your Script Editor:                                                        #
#                   1. Open the Script Editor.                                                                        #
#                   2. Select "PowerShell Libraries" from the File menu.                                              #
#                   3. Check the Add-on.SnippetManager module.                                                        #
#                   4. Click on OK to close the "PowerShell Libraries" dialog.                                        #
#                   Alternatively you can load the module from the embedded console by invoking this:                 #
#                       Import-Module -Name Add-on.SnippetManager                                                     #
#                   Please provide feedback on the PowerGUI Forums.                                                   #
#######################################################################################################################

Set-StrictMode -Version 2

#region Initialize the Script Editor Add-on.

if ($Host.Name –ne 'PowerGUIScriptEditorHost') { return }
if ($Host.Version -lt '2.3.0.0000') {
	[System.Windows.Forms.MessageBox]::Show("The ""$(Split-Path -Path $PSScriptRoot -Leaf)"" Add-on module requires version 2.3.0.0000 or later of the Script Editor. The current Script Editor version is $($Host.Version).$([System.Environment]::NewLine * 2)Please upgrade to version 2.2.0.1358 and try again.","Version 2.3.0.0000 or later is required",[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
	return
}

$pgse = [Quest.PowerGUI.SDK.ScriptEditorFactory]::CurrentInstance

#endregion

#region Load resources from disk.

$iconLibrary = @{
	# TODO: Load icons into this table.
	SnipManIcon16 = New-Object System.Drawing.Icon -ArgumentList "$PSScriptRoot\Resources\ico\snippeticonPG.ico",16,16
	SnipManIcon32 = New-Object System.Drawing.Icon -ArgumentList "$PSScriptRoot\Resources\ico\snippeticonPG.ico",32,32
}

$imageLibrary = @{
	# TODO: Load images into this table.
	SnipManImage16 = $iconLibrary['SnipManIcon16'].ToBitmap()
	SnipManImage32 = $iconLibrary['SnipManIcon32'].ToBitmap()
}

#endregion

#region Variables
  $scriptpath = "`""+(Split-Path -parent $MyInvocation.MyCommand.Definition)+"\SnipMan.ps1"+"`""
#endregion


#region Create the SnipMan Console command. 

 function startprocess {
                $file, [string]$arguments = $args;
                $psi = new-object System.Diagnostics.ProcessStartInfo $file;
                $psi.Arguments = $arguments;
				$psi.UseShellExecute = $False
				$psi.CreateNoWindow = $true
                $psi.WorkingDirectory = get-location;
                [void][System.Diagnostics.Process]::Start($psi);
}
 
if (-not ($SnipManCommand = 
$pgse.Commands['ToolsCommand.SnipMan'])) { 
  $SnipManCommand = New-Object -TypeName Quest.PowerGUI.SDK.ItemCommand -ArgumentList 'ToolsCommand','SnipMan' 
  $SnipManCommand.Text = 'Snippet Manager' 
  $SnipManCommand.Image = $imageLibrary['SnipManImage16'] 
  #$SnipManCommand.AddShortcut('Ctrl+Shift+M') 
  $SnipManCommand.ScriptBlock ={
  
  	#Region - SnipMan Scriptblock-
    startprocess "$env:windir\system32\WindowsPowerShell\v1.0\powershell.exe" '-noprofile' '-windowstyle hidden' '-STA' '-File' $scriptpath
  	#endregion 
	
  }
 
  $pgse.Commands.Add($SnipManCommand) 
} 
 
#endregion 




#region Create the SnipMan Console menu item in the Tools menu. 
 
if (($toolsmenu = $pgse.Menus['MenuBar.Tools']) -and  (-not ($SnipManMenuItem = $toolsmenu.Items['ToolsCommand.SnipMan']))) { 
  $toolsmenu.Items.Add($SnipManCommand) 
  if ($SnipManMenuItem = $toolsmenu.Items['ToolsCommand.SnipMan']) { 
  $SnipManMenuItem.FirstInGroup = $true 
  } 
} 
 
#endregion 
 
#region Clean-up the Add-on when it is removed. 
 
$ExecutionContext.SessionState.Module.OnRemove = { 
		$pgse = [Quest.PowerGUI.SDK.ScriptEditorFactory]::CurrentInstance 

		#region Remove the SnipMan Console menu item from the Tools menu. 

		if (($toolsmenu = $pgse.Menus['MenuBar.tools']) -and  ($SnipManMenuItem = $toolsmenu.Items['ToolsCommand.SnipMan'])) { 
			$toolsmenu.Items.Remove($SnipManMenuItem) | Out-Null 
		} 

		#endregion 

		#region Remove the SnipMan Console command. 

		if ($SnipManCommand = $pgse.Commands['ToolsCommand.SnipMan']) { 
			$pgse.Commands.Remove($SnipManCommand) | Out-Null 
		} 

		#endregion 
} 
 
#endregion 
