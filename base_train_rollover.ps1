<#
.SYNOPSIS
  Rollback training database for WellSky EPMA/JAC

.DESCRIPTION
  This script performs the following:
    1. Stops the train environment
    2. Renames current database 
    3. Copies base train database
    4. Starts the train environment

.EXAMPLE
  Create a scheduled task with the following:

    Action: Start a program
    Program/script: Powershell.exe
    Arguments: -ExecutionPolicy Bypass <path to folder>\base_train_rollover.ps1
  
.LINK
  https://github.com/richard-sistern

.NOTES
  Please take a backup (with cache turned off) of your training database before testing this script

  This script will always keep one previous version of the database
#>


# Log file path
$log_file = "<path to folder>\rollover.log"

# Path of the training database
$train_db_path = "<drive>\JACDatabasesTRAIN"
# Path to the seed database this script restores from
$base_db_path = "<path to folder>\JACDatabasesTRAIN"
# Path to back the database to
$backup_db_path = "<path to folder>\JACDatabasesTRAIN_Orig"

# Cache environment name (default provided)
$cache_env = "TRAIN"
# Cache control executable path (default provided) 
$cache_control = "C:\InterSystems\Train\bin\ccontrol.exe"


function Logger {
  <#
    .SYNOPSIS
    Log messages to a file

    .DESCRIPTION
    Appends formatted log messages to location specified in <$log_file>
    
    .OUTPUTS
    I, 23/09/2020 10:39:59 INFO -- : An informational message
    E, 23/09/2020 10:40:00 ERROR -- : An error message

    .EXAMPLE
    Logger -message "Log an info message"
    Logger -message "Log an error" -level "ERROR"
  #>
  param (
    # Log entry message
    [parameter(mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$message
    ,
    # Log entry message level (default:INFO)
    [parameter(mandatory = $false)]
    [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR')]
    [string]$level = 'INFO'
		)

  $str = $level.subString(0, 1) + ", " + (Get-Date).ToString() + " " + $level + " -- : " + $message

  Add-Content -Path $log_file -Value $str
} # Logger function

<#
  __  __   _   ___ _  _ 
 |  \/  | /_\ |_ _| \| |
 | |\/| |/ _ \ | || .` |
 |_|  |_/_/ \_\___|_|\_|
                                            
#>


Logger -message "Stopping CACHE environment $($cache_env)"
Start-Process $cache_control -ArgumentList "stop $cache_env" -Wait

Start-Sleep -s 60  

if (Test-Path $backup_db_path) {
    Logger -message "Removing $backup_db_path" 
    Remove-Item $backup_db_path -Force -Recurse
}

Start-Sleep -s 10 

Logger -message "Renaming folder"

try {
    Rename-Item -Path $train_db_path -newName $backup_db_path -ErrorAction Stop
}
catch {
    Logger -level "ERROR" -message "Unable to rename $($train_db_path) to $backup_db_path"
    Logger -level "ERROR" -message "This may be due to WellSky being connected and accessing $cache_env"
    Exit
}

Start-Sleep -s 60

Logger -message "Started copying BASE"
Copy-Item -Path $base_db_path -Destination $train_db_path -Recurse
Logger -message "Finished copying BASE"

Start-Sleep -s 300
Logger -message "Starting CACHE environemnt $($cache_env)"
Start-Process $cache_control -ArgumentList "start $cache_env" -Wait