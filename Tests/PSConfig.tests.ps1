$ParentPath = Split-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent) -Parent
Import-Module -Name (Join-Path -Path $ParentPath -ChildPath "PSConfig.psm1")


Describe Add-DefaultConfigurationSource {
    Clear-ConfigurationSource
    InModuleScope PSConfig {
        It "Creates a Default Configuration Source" {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-DefaultConfigurationSource -InputObject @{
                Data = "Hello, World!"
            }
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "Default Values"
            $Script:ConfigurationSources[0].Type | Should BeExactly "Default"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
        }
    }
}


Describe Add-EnvironmentConfigurationSource {
    Clear-ConfigurationSource
    InModuleScope PSConfig {
        It "Creates an Environment Variable Configuration Source" {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-EnvironmentConfigurationSource
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "Environment Variables"
            $Script:ConfigurationSources[0].Type | Should BeExactly "Environment"
        }
    }
}


Describe Add-FileConfigurationSource {
    Clear-ConfigurationSource
    It "Creates a Configuration Source from a string data file" {
        Mock -ModuleName PSConfig Get-Content { return 'Data = Hello, World!' }
        Mock -ModuleName PSConfig Test-Path { return $true }

        InModuleScope PSConfig {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-FileConfigurationSource -Path "C:\NotARealPath\Test.txt" -Format "StringData"
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "C:\NotARealPath\Test.txt"
            $Script:ConfigurationSources[0].Type | Should BeExactly "File/StringData"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
        }
    }

    Clear-ConfigurationSource
    It "Creates a Configuration Source from a Json file" {
        Mock -ModuleName PSConfig Get-Content { return '{"Data": "Hello, World!"}' }
        Mock -ModuleName PSConfig Test-Path { return $true }

        InModuleScope PSConfig {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-FileConfigurationSource -Path "C:\NotARealPath\Test.json" -Format "Json"
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "C:\NotARealPath\Test.json"
            $Script:ConfigurationSources[0].Type | Should BeExactly "File/Json"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
        }
    }

    Clear-ConfigurationSource
    It "Creates a Configuration Source from a Csv file" {
        Mock -ModuleName PSConfig Import-Csv { return "Data`n" + '"Hello, World!"' | ConvertFrom-Csv }
        Mock -ModuleName PSConfig Test-Path { return $true }

        InModuleScope PSConfig {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-FileConfigurationSource -Path "C:\NotARealPath\Test.csv" -Format "Csv"
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "C:\NotARealPath\Test.csv"
            $Script:ConfigurationSources[0].Type | Should BeExactly "File/Csv"
            $Script:ConfigurationSources[0].Data.PSObject.Properties.Count | Should Be 1
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
        }
    }
}

Describe Add-FileConfigurationSourceMultiline {
    Clear-ConfigurationSource
    It "Creates a Configuration Source from a string data file with multiple lines" {
        Mock -ModuleName PSConfig Get-Content { return "Data = Hello, World!`r`nSecondLine = Some more`r`nThirdLine = This is the Third Line" }
        Mock -ModuleName PSConfig Test-Path { return $true }

        InModuleScope PSConfig {
            $Script:ConfigurationSources.Count | Should Be 0
            Add-FileConfigurationSource -Path "C:\NotARealPath\Test.txt" -Format "StringData"
            $Script:ConfigurationSources.Count | Should Be 1
            $Script:ConfigurationSources[0].Name | Should BeExactly "C:\NotARealPath\Test.txt"
            $Script:ConfigurationSources[0].Type | Should BeExactly "File/StringData"
            ($Script:ConfigurationSources[0].Data.PSObject.Properties | Measure-Object).Count | Should Be 3
            $Script:ConfigurationSources[0].Data.Data | Should BeExactly "Hello, World!"
            $Script:ConfigurationSources[0].Data.SecondLine | Should BeExactly "Some more"
            $Script:ConfigurationSources[0].Data.ThirdLine | Should BeExactly "This is the Third Line"
        }
    }
}

Describe Clear-ConfigurationSource {
    Clear-ConfigurationSource
    Add-DefaultConfigurationSource -InputObject @{
        Data = "Hello, World!"
    }
    InModuleScope PSConfig {
        It "Clears the configuration" {
            $Script:ConfigurationSources.Count | Should Be 1
            Clear-ConfigurationSource
            $Script:ConfigurationSources.Count | Should Be 0
        }
    }
}


Describe Get-ConfigurationItem {
    Clear-ConfigurationSource
    Context "No data loaded" {
        It "Returns null" {
            Get-ConfigurationItem -Key "Nonexistent" | Should BeNullOrEmpty
        }
    }

    Add-EnvironmentConfigurationSource
    Context "Environment Variables" {
        It "Returns null when nothing is found" {
            Get-ConfigurationItem -Key "Data" | Should BeNullOrEmpty
        }

        It "Returns environment variables" {
            Get-ConfigurationItem -Key "PSModulePath" | Should BeExactly $env:PSModulePath
        }
    }

    Clear-ConfigurationSource
    Add-DefaultConfigurationSource -InputObject @{
        Data = "Hello, World!"
    }
    Context "Object Values" {
        It "Returns null when nothing is found" {
            Get-ConfigurationItem -Key "Nonexistent" | Should BeNullOrEmpty
        }

        It "Returns data" {
            Get-ConfigurationItem -Key "Data" | Should BeExactly "Hello, World!"
        }
    }

    Clear-ConfigurationSource
    Add-EnvironmentConfigurationSource
    Add-DefaultConfigurationSource -InputObject @{
        Data = "Hello, World!"
    }
    Context "Multiple Values" {
        It "Returns null when nothing is found" {
            Get-ConfigurationItem -Key "Nonexistent" | Should BeNullOrEmpty
        }

        It "Returns data when found in first configuration source" {
            Get-ConfigurationItem -Key "PSModulePath" | Should BeExactly $env:PSModulePath
        }

        It "Returns data when found in second configuration source" {
            Get-ConfigurationItem -Key "Data" | Should BeExactly "Hello, World!"
        }
    }
}


Remove-Module -Name "PSConfig"