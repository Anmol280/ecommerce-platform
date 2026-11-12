param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
$nginxStopped = $false
$base = $BaseUrl.TrimEnd("/")

function Assert-ApiContainerResponds {
    & docker compose exec -T api python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/ready', timeout=3)" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "The API did not remain ready during the proxy recovery drill."
    }
}

try {
    $null = Invoke-RestMethod -Uri "$base/health/live" -TimeoutSec 5
    Assert-ApiContainerResponds

    & docker compose stop nginx | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not stop the Nginx service for the recovery drill."
    }
    $nginxStopped = $true

    $failureDetected = $false
    try {
        $response = Invoke-WebRequest -Uri "$base/health/live" -TimeoutSec 4
        $failureDetected = [int]$response.StatusCode -ne 200
    }
    catch {
        $failureDetected = $true
    }
    if (-not $failureDetected) {
        throw "The proxy failure was not detected: the request still returned success."
    }
    Assert-ApiContainerResponds
    Write-Output "PASS Proxy outage detected while API remained ready"
}
finally {
    if ($nginxStopped) {
        & docker compose start nginx | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "Could not restart Nginx after the recovery drill."
        }

        $recovered = $false
        for ($attempt = 0; $attempt -lt 30; $attempt++) {
            try {
                $live = Invoke-RestMethod -Uri "$base/health/live" -TimeoutSec 3
                $ready = Invoke-RestMethod -Uri "$base/health/ready" -TimeoutSec 3
                if ($live.status -eq "ok" -and $ready.status -eq "ready") {
                    $recovered = $true
                    break
                }
            }
            catch {
                Start-Sleep -Seconds 2
            }
            if (-not $recovered) {
                Start-Sleep -Seconds 2
            }
        }
        if (-not $recovered) {
            Pop-Location
            throw "Nginx restarted, but health and readiness did not recover within 60 seconds."
        }
        Write-Output "PASS Proxy restart restored liveness and database readiness"
    }
    Pop-Location
}
