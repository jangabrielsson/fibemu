<#
in windows 11:
run PowerShell
set rights for running script: Set-ExecutionPolicy RemoteSigned
run script in your folder: .\kill-port.ps1 5004
result should be: SUCCESS: The process with PID xxxxx has been terminated.
#>
param ($port)

$foundProcesses = netstat -ano | findstr :$port
$activePortPattern = ":$port\s.+LISTENING\s+\d+$"
$pidNumberPattern = "\d+$"

IF ($foundProcesses | Select-String -Pattern $activePortPattern -Quiet) {
  $matches = $foundProcesses | Select-String -Pattern $activePortPattern
  $firstMatch = $matches.Matches.Get(0).Value

  $pidNumber = [regex]::match($firstMatch, $pidNumberPattern).Value

  taskkill /pid $pidNumber /f
}
