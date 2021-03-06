function Get-PropertySet
{
    <#
    .Synopsis
        Gets the property sets
    .Description
        Gets the property sets.  Property sets are predefined views of an object.
    .Example
        Get-PropertySet
    .Example
        Get-PropertySet -TypeName System.Diagnostics.Process             
    #>
    
    [OutputType([PSObject])]
    param(    
    # The name of the typename to get
    [string[]]
    $TypeName    
    )
    
    
    begin {
        $typeFiles = (Get-ChildItem $psHome -Filter *types.ps1xml) + 
            @(Get-Module  | ? { $_.ExportedTypeFiles }  | %{ $_.ExportedTypeFiles | Get-Item })
    }
    process {    
        $typefiles | 
            Select-Xml //PropertySet | 
            Where-Object {
                $_.Node.parentnode.parentnode.name -ne 'PSStandardMembers' -and (
                (-not $typeName) -or ($typename -contains $_.Node.parentnode.parentnode.name)
                )
            }  | 
            Select-Object @{
                Name='Typename';
                Expression={$_.Node.parentnode.parentnode.name}
            }, @{
                Name='PropertySet';
                Expression = {$_.Node.Name }
            }   
    }
}
 
