Function Suspend-Script-Execution
{
	# If running in the console, wait for input before closing.
	if ($Host.Name -eq "ConsoleHost")
	{ 
		Write-Host "Press any key to continue..."
		$Host.UI.RawUI.FlushInputBuffer()   # Make sure buffered input doesn't "press a key" and skip the ReadKey().
		$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
	}
}

Function Start-Log([string]$TranscriptFile)
{
	$ErrorActionPreference="SilentlyContinue"
	Stop-Transcript | out-null
	$ErrorActionPreference = "Continue"
	Start-Transcript -path $TranscriptFile -Append
}

Function Stop-Log
{
	$ErrorActionPreference="SilentlyContinue"
	Stop-Transcript | out-null
	$ErrorActionPreference = "Continue" # or "Stop"
}

Function FormatElapsedTime($ts) 
{
    $elapsedTime = ""

    if ( $ts.Minutes -gt 0 )
    {
        $elapsedTime = [string]::Format( "{0:00} min. {1:00}.{2:00} sec.", $ts.Minutes, $ts.Seconds, $ts.Milliseconds / 10 );
    }
    else
    {
        $elapsedTime = [string]::Format( "{0:00}.{1:00} sec.", $ts.Seconds, $ts.Milliseconds / 10 );
    }

    if ($ts.Hours -eq 0 -and $ts.Minutes -eq 0 -and $ts.Seconds -eq 0)
    {
        $elapsedTime = [string]::Format("{0:00} ms.", $ts.Milliseconds);
    }

    if ($ts.Milliseconds -eq 0)
    {
        $elapsedTime = [string]::Format("{0} ms", $ts.TotalMilliseconds);
    }

    return $elapsedTime
}

Function TimedCommandBlock($step, $block)
{
	Write-Verbose "`r`n"
	Write-Verbose "-------------------------------------------------"
    Write-Verbose "   [ $step ]"
	Write-Verbose "-------------------------------------------------"

    $sw = [Diagnostics.Stopwatch]::StartNew()
    &$block
    $sw.Stop()
    $time = $sw.Elapsed
    $formatTime = FormatElapsedTime $time

    Write-Verbose "`t Step completed in $formatTime"
}

Function Get-SemVer
{
	param( [string]$InputString )
	$pattern = [regex]".*-(\d+\.\d+\.\d+\.\d+).*"
	$m = $pattern.Match($InputString)
	$m.Groups[1].Value
}

Function Get-NewestFile
{
	param ( [string]$Path, [string]$Filter )
	$FileName = Get-ChildItem $Path -Filter $Filter | Sort-Object LastWriteTime -Descending | Select-Object -First 1
	return $FileName
}