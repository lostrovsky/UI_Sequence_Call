# Manual console launcher. Closes when you Ctrl-C or close the window.
# Reads UISequenceCall.properties from this directory regardless of the
# caller's current working directory.
#
# Usage:
#   .\run.ps1                          # launch with defaults
#   .\run.ps1 --log-output=console     # any args are passed straight through to the jar
Set-Location $PSScriptRoot
& java -jar ui-sequence-call-1.0.0-jar-with-dependencies.jar @args
$exitCode = $LASTEXITCODE
# Hold the window open so the operator can see final output (matches run.cmd).
# Skip the pause when invoked from an existing PowerShell session that already
# has its own scrollback (-NonInteractive or piped stdin).
if ($Host.UI.RawUI -and -not [Console]::IsInputRedirected) {
    Write-Host ""
    Write-Host "Service exited with code $exitCode. Press Enter to close..." -ForegroundColor Cyan
    [void](Read-Host)
}
exit $exitCode
