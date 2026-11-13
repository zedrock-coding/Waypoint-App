param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter Supabase service_role key or secret key")]
    [string]$ApiKey
)

$url = "https://eknzdxexfcfdmqvbyvxt.supabase.co/rest/v1/feedback?select=*&order=created_at.desc"
$headers = @{
    "apikey"        = $ApiKey.Trim()
    "Authorization" = "Bearer " + $ApiKey.Trim()
}

try {
    $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    if ($response.Count -eq 0) {
        Write-Host "No feedback records found." -ForegroundColor Yellow
    } else {
        Write-Host ("Found {0} feedback entries:`n" -f $response.Count) -ForegroundColor Green
        $response | Format-Table -Property created_at, name, email, message -Wrap
    }
} catch {
    Write-Host ("Failed to fetch feedback: " + $_.Exception.Message) -ForegroundColor Red
}
