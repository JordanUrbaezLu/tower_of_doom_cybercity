param([string]$Action='capture',[int]$X,[int]$Y,[string]$Text,[string]$Keys,[string]$Task='',
      [string]$SessionDir='C:\Users\jorda\Documents\BO3_tools\BO6_Pilot\saluki_session_20260911')
$ErrorActionPreference='Stop'
$leasePath='C:\Users\jorda\Documents\BO3_tools\BO6_Pilot\saluki_active_task.json'
if (Test-Path -LiteralPath $leasePath) {
    $lease=Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json
    if ([DateTimeOffset]::Parse($lease.expires) -gt [DateTimeOffset]::Now -and $lease.task -ne $Task) {
        throw ('Saluki is reserved for '+$lease.task+': '+$lease.reason+'. Wait for that task to release it; no input sent.')
    }
}
if ($Action -eq 'text' -and $Text.Length -gt 12) {
    # Use a separate acknowledged/captured request for each short fragment.
    # In-controller sleeps alone still lost a fragment in a live long batch.
    # This also fixes callers that submit an entire hash filter in one call.
    $lastReceipt=$null
    for ($offset=0; $offset -lt $Text.Length; $offset+=12) {
        $lastReceipt=& $PSCommandPath -Action text -Text ($Text.Substring($offset,[Math]::Min(12,$Text.Length-$offset))) -Task $Task -SessionDir $SessionDir
        $fragment=($lastReceipt -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
        if (-not $fragment.ok) { throw 'A text fragment was not acknowledged; no further input sent' }
    }
    Write-Output $lastReceipt
    exit 0
}
$folder=$SessionDir
$indices=@(Get-ChildItem -LiteralPath $folder -Filter 'request_*.json' | ForEach-Object {
    if ($_.BaseName -match '^request_(\d+)$') { [int]$Matches[1] }
})
$sequence=1
if ($indices.Count) { $sequence=1+[int]($indices | Measure-Object -Maximum).Maximum }
$base='request_{0:d3}' -f $sequence
$target=Join-Path $folder ($base+'.json')
$result=Join-Path $folder ('result_{0:d3}.json' -f $sequence)
$command=@{action=$Action;x=$X;y=$Y;text=$Text;keys=$Keys}
$staging=Join-Path $folder ($base+'.pending')
$command | ConvertTo-Json | Set-Content -LiteralPath $staging -Encoding UTF8
Move-Item -LiteralPath $staging -Destination $target
$deadline=[DateTime]::UtcNow.AddSeconds(15)
$response=$null
while ($null -eq $response) {
    if ([DateTime]::UtcNow -gt $deadline) { throw ('Saluki helper has not returned a complete receipt: '+$target) }
    if (Test-Path -LiteralPath $result) {
        # The controller may still hold the result file just after it appears.
        # Retry only this read; never replay a click/search because of the race.
        try {
            $candidate=Get-Content -LiteralPath $result -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $candidate -and $null -ne $candidate.ok) { $response=$candidate }
        } catch { }
    }
    if ($null -eq $response) { Start-Sleep -Milliseconds 100 }
}
$response | Select-Object ok,action,error,screenshot,window | ConvertTo-Json
if (-not $response.ok) { exit 1 }
