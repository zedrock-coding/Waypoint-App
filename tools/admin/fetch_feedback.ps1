param (
    [string]$ApiKey,
    [switch]$Open
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$keyFile = Join-Path $scriptDir "key.txt"
$outFile = Join-Path $scriptDir "feedback_data.js"
$htmlFile = Join-Path $scriptDir "admin.html"

if (-not $ApiKey) {
    if (Test-Path $keyFile) {
        $ApiKey = (Get-Content $keyFile -Raw).Trim()
    } elseif ($env:SUPABASE_SERVICE_ROLE_KEY) {
        $ApiKey = $env:SUPABASE_SERVICE_ROLE_KEY.Trim()
    }
}

if (-not $ApiKey) {
    Write-Host "Missing API key." -ForegroundColor Red
    Write-Host "Pass -ApiKey, or save key in tools/admin/key.txt." -ForegroundColor Yellow
    exit 1
}

$url = "https://eknzdxexfcfdmqvbyvxt.supabase.co/rest/v1/feedback?select=*&order=created_at.desc"
$headers = @{
    "apikey"        = $ApiKey.Trim()
    "Authorization" = "Bearer " + $ApiKey.Trim()
}

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -UserAgent "WaypointAdmin/1.0"
    
    # Handle single object or array correctly
    $items = @($response)
    if ($items.Count -eq 0) {
        $json = "[]"
    } else {
        $json = $items | ConvertTo-Json -Depth 5
    }
    $jsContent = "window.FEEDBACK_RECORDS = " + $json + ";"
    Set-Content -Path $outFile -Value $jsContent -Encoding UTF8

    Write-Host ("Exported {0} record(s) to {1}" -f $items.Count, (Split-Path -Leaf $outFile)) -ForegroundColor Green

    if ($items.Count -gt 0) {
        $items | Format-Table -Property created_at, name, email, message -Wrap
    } else {
        Write-Host "Database returned 0 feedback rows." -ForegroundColor Yellow
    }

    Write-Host "Open or refresh tools/admin/admin.html to view cards in browser.`n" -ForegroundColor Cyan

    if ($Open) {
        Start-Process $htmlFile
    }
} catch {
    Write-Host ("Failed to fetch feedback: " + $_.Exception.Message) -ForegroundColor Red
}
