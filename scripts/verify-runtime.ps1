param(
    [string]$BaseUrl = "http://localhost:8080"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

function Assert-Equal {
    param(
        [string]$Name,
        [object]$Actual,
        [object]$Expected
    )

    if ($Actual -ne $Expected) {
        throw "$Name expected $Expected but received $Actual."
    }
    Write-Output "PASS $Name ($Actual)"
}

function Get-HttpStatus {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Headers = @{},
        [string]$Body = ""
    )

    try {
        $request = @{
            Uri        = $Uri
            Method     = $Method
            TimeoutSec = 10
            Headers    = $Headers
        }
        if ($Body) {
            $request.ContentType = "application/json"
            $request.Body = $Body
        }
        $response = Invoke-WebRequest @request
        return [int]$response.StatusCode
    }
    catch {
        if ($_.Exception.Response) {
            return [int]$_.Exception.Response.StatusCode
        }
        throw
    }
}

try {
    $base = $BaseUrl.TrimEnd("/")
    $envValues = @{}
    $envPath = Join-Path $projectRoot ".env"
    if (Test-Path -LiteralPath $envPath) {
        foreach ($line in Get-Content -LiteralPath $envPath) {
            if ($line -match '^\s*([^#=]+)=(.*)$') {
                $envValues[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }

    $adminToken = $envValues["ADMIN_TOKEN"]
    if (-not $adminToken) {
        $adminToken = "local-admin-token"
    }

    $live = Invoke-RestMethod -Uri "$base/health/live" -TimeoutSec 10
    Assert-Equal "Liveness" $live.status "ok"

    $ready = Invoke-RestMethod -Uri "$base/health/ready" -TimeoutSec 10
    Assert-Equal "Database readiness" $ready.status "ready"

    Assert-Equal "Swagger UI" (Get-HttpStatus "$base/docs") 200

    $products = Invoke-RestMethod -Uri "$base/api/v1/products?q=wireless&limit=2" -TimeoutSec 10
    $productRows = @($products)
    if ($productRows.Count -eq 0) {
        throw "No wireless demo product was found. Run 'docker compose exec api python -m scripts.seed_demo_data' first."
    }
    Write-Output "PASS Product search ($($productRows.Count) result(s))"
    Assert-Equal "Product detail" (Get-HttpStatus "$base/api/v1/products/$($productRows[0].id)") 200

    Assert-Equal "Admin rejects missing token" (Get-HttpStatus "$base/api/v1/admin/audit-events") 401
    $adminHeaders = @{ "X-Admin-Token" = $adminToken }
    Assert-Equal "Admin accepts configured token" (Get-HttpStatus "$base/api/v1/admin/audit-events" -Headers $adminHeaders) 200

    $invalidOrder = '{"customer_email":"not-an-email","items":[]}'
    $orderHeaders = @{ "Idempotency-Key" = "invalid-order-check-1" }
    Assert-Equal "Order validation" (Get-HttpStatus "$base/api/v1/orders" -Method "POST" -Headers $orderHeaders -Body $invalidOrder) 422
    Assert-Equal "Missing order lookup" (Get-HttpStatus "$base/api/v1/orders/2147483647") 404

    $migrationOutput = (& docker compose exec -T api alembic current 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $migrationOutput -notmatch "\(head\)") {
        throw "Database migration is not at head."
    }
    Write-Output "PASS Database migration is at head"
}
finally {
    Pop-Location
}
