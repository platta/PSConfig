<#
.SYNOPSIS
Creates a layer of abstraction above reading configuration data.
#>

# Load strings file
$CurrentPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Import-LocalizedData -BindingVariable r -BaseDirectory (Join-Path -Path $CurrentPath -ChildPath "Localized")
$Script:r = $r

# This array keeps track of all the configuration sources that have been added.
$Script:ConfigurationSources = @()

Function Get-ConfigurationItem {
    <#
    .SYNOPSIS
    Gets a piece of configuration data from the first source that contains the
    specified key.

    .DESCRIPTION
    Gets a piece of configuration data from the first source that contains the
    specified key. Configuration sources are searched in the order in which they
    were loaded.

    .PARAMETER Key
    Specifies the key to retrieve a value for.

    .OUTPUTS
    Variant. The output type depends on the contents of the configuration data.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    Process {
        $ReturnValue = $null
        foreach ($Item in $Script:ConfigurationSources) {
            Write-Verbose -Message ([string]::Format($Script:r.SearchingForItem_F0_In_F1_Type_F2, $Key, $Item.Name, $Item.Type))
            if ($Item.Type -eq "Environment") {
                if (Test-Path -Path "Env:\$Key") {
                    Write-Verbose -Message ([string]::Format($Script:r.Item_F0_Found, $Key))
                    $ReturnValue = (Get-Item -Path "Env:\$Key").Value
                    break
                }
            } else {
                $Property = $Item.Data.PSObject.Properties | Where-Object -FilterScript { $_.Name -eq $Key }
                if ($Property) {
                    Write-Verbose -Message ([string]::Format($Script:r.Item_F0_Found, $Key))
                    $ReturnValue = $Property.Value
                    break
                }
            }
        }

        return $ReturnValue
    }
}

Function Add-DefaultConfigurationSource {
    <#
    .SYNOPSIS
    Adds a configuration source with explicitly specified values.

    .DESCRIPTION
    Adds a configuration source with explicitly specified values. This can be
    useful for specifying fallback values that may not be present in a user's
    specific configuration.

    .PARAMETER InputObject
    Specifies configuration data.

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [PSCustomObject[]]$InputObject
    )

    Process {
        foreach ($Item in $InputObject) {
            # The data coming in should be a PSCustomObject already, but in case
            # it's not convert it.
            if ($Item -is [hashtable]) {
                $Item = New-Object -TypeName PSObject -Property $Item
            }

            $NewSource = New-Object -TypeName PSObject -Property @{
                Name = "Default Values"
                Type = "Default"
                Data = $Item
            }

            Write-Verbose -Message ([string]::Format($Script:r.AddingSource_F0_Type_F1, $NewSource.Name, $NewSource.Type))
            $Script:ConfigurationSources += $NewSource
        }
    }
}

Function Add-FileConfigurationSource {
    <#
    .SYNOPSIS
    Adds a configuration source from the specified file.

    .DESCRIPTION
    Adds a configuration source from the specified file. Files can be formatted
    in three different ways:
        StringData - The file will be imported and passed to
                     ConvertFrom-StringData
        Json - The file can be parsed using ConvertFrom-Json.
        Csv - The file can be parsed using Import-Csv. Only the first row will
              be read.

    .PARAMETER Path
    Specifies the path to the configuration file.

    .PARAMETER Format
    Specifies the format the configuration file is written in.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [string[]]$Path,

        [Parameter(
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateSet("StringData", "Json", "Csv")]
        [string]$Format = "StringData"
    )

    Process {
        foreach ($Item in $Path) {
            if (!(Test-Path -Path $Item)) {
                # The file may not exist, that's part of making this flexible,
                # so it's not an error.
                Write-Verbose -Message ([string]::Format($Script:r.File_F0_NotFound, $Item))
                continue
            }
            $NewSource = $null
            switch ($Format) {
                "StringData" {
                    try {
                        $HashData = Get-Content -Path $Item -Raw -ErrorAction Stop | ConvertFrom-StringData -ErrorAction Stop
                        $Data = New-Object -TypeName PSObject -Property $HashData -ErrorAction Stop

                        $NewSource = New-Object -TypeName PSObject -Property @{
                            Type = "File/StringData"
                            Name = $Item
                            Data = $Data
                        } -ErrorAction Stop
                    } catch {
                        Write-Error -Exception $_.Exception -Message ([string]::Format($Script:r.CannotLoad_F0_Data_F1, "StringData", $Item))
                    }
                }

                "Json" {
                    try {
                        $Data = Get-Content -Path $Item -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

                        $NewSource = New-Object -TypeName PSObject -Property @{
                            Type = "File/Json"
                            Name = $Item
                            Data = $Data
                        } -ErrorAction Stop
                    } catch {
                        Write-Error -Exception $_.Exception -Message ([string]::Format($Script:r.CannotLoad_F0_Data_F1, "Json", $Item))
                    }
                }

                "Csv" {
                    try {
                        $Data = Import-Csv -Path $Item -ErrorAction Stop | Select-Object -First 1 -ErrorAction Stop

                        $NewSource = New-Object -TypeName PSObject -Property @{
                            Type = "File/Csv"
                            Name = $Item
                            Data = $Data
                        } -ErrorAction Stop
                    } catch {
                        Write-Error -Exception $_.Exception -Message ([string]::Format($Script:r.CannotLoad_F0_Data_F1, "Csv", $Item))
                    }
                }
            }

            if ($NewSource) {
                Write-Verbose -Message ([string]::Format($Script:r.AddingSource_F0_Type_F1, $NewSource.Name, $NewSource.Type))
                $Script:ConfigurationSources += $NewSource
            }
        }
    }
}

Function Add-EnvironmentConfigurationSource {
    <#
    .SYNOPSIS
    Adds the current session's environment variables as a configuration source.

    .DESCRIPTION
    Adds the current session's environment variables as a configuration source.

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    Param ()

    Process {
        $NewSource = New-Object -TypeName PSObject -Property @{
            Type = "Environment"
            Name = "Environment Variables"
            Data = $null
        }

        Write-Verbose -Message ([string]::Format($Script:r.AddingSource_F0_Type_F1, $NewSource.Name, $NewSource.Type))
        $Script:ConfigurationSources += $NewSource
    }
}

Function Clear-ConfigurationSource {
    <#
    .SYNOPSIS
    Clears all currently loaded configuration sources.

    .DESCRIPTION
    Clears all currently loaded configuration sources.

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    Param ()

    Process {
        Write-Verbose -Message $Script:r.ClearingSources
        $Script:ConfigurationSources = @()
    }
}
