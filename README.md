# PSConfig
PSConfig is a module to simplify the use of configuration data and configuration files. It supports providing multiple sources of configuration data (in key value pairs) and will check these sources in order when asked to retrieve the value for a particular key.

## Usage
Here is an example illustrating the most common scenario, providing default values that can be overridden using a configuration file.

```powershell
# Import the module.
Import-Module PSConfig

# Load the configuration file (if it exists).
Add-FileConfigurationSource -Path "C:\ps\config.csv" -Format "Csv"

# Provide default values as a fallback.
Add-DefaultConfigurationSource -InputObject @{
	Message = "Hello, World!"
}

# Look up a configuration value.
$Message = Get-ConfigurationItem -Key "Message"

# Output to the screen.
Write-Host $Message
```

The order in which the Configuration Sources are added is important. In this example, the configuration file will be searched first, and the default values second.

## Supported Configuration Sources
PSConfig supports loading configuration data from the following sources:

- Default values provided explicitly in the code
- Values from a file in a supported format
	- StringData - plain text format with a single value assigment such as "Data = Value" on each line.
	- Json - standard JSON format.
	- Csv - Comma Separated Values with a header row and one row of data.
- Values taken from Environment Variables.

## Installation
Copy the module into a folder in your PowerShell Module Path. You can check `$env:PSModulePath` in a PowerShell session if unsure what paths are included, but starting in PowerShell v4.0 the standard is `C:\Program Files\WindowsPowerShell\Modules`. Don't put the code directly into the Modules folder, it must be in a subfolder named `PSConfig`.
