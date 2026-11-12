param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 18081
)

$ErrorActionPreference = "Stop"
$containerName = "ecommerce-api-smoke-$([guid]::NewGuid().ToString('N'))"
$baseUrl = "http://127.0.0.1:$Port"
$started = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot

function Assert-Equal {
    param([string]$Name, [object]$Actual, [object]$Expected)
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
    $request = [System.Net.HttpWebRequest]::Create($Uri)
    $request.Method = $Method
    $request.Timeout = 10000
    foreach ($headerName in $Headers.Keys) {
        $request.Headers[$headerName] = [string]$Headers[$headerName]
    }
    if ($Body) {
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $request.ContentType = "application/json"
        $request.ContentLength = $bodyBytes.Length
        $requestStream = $request.GetRequestStream()
        try {
            $requestStream.Write($bodyBytes, 0, $bodyBytes.Length)
        }
        finally {
            $requestStream.Dispose()
        }
    }

    try {
        $response = $request.GetResponse()
        try {
            return [int]$response.StatusCode
        }
        finally {
            $response.Close()
        }
    }
    catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
            $_.Exception.Response.Close()
            return $statusCode
        }
        throw
    }
}

try {
    $randomBytes = New-Object byte[] 32
    $randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $randomGenerator.GetBytes($randomBytes)
        $adminToken = [Convert]::ToBase64String($randomBytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
    }
    finally {
        $randomGenerator.Dispose()
    }

    & docker run --rm --detach `
        --name $containerName `
        --read-only `
        --tmpfs /tmp:rw,nosuid,size=64m `
        --publish "127.0.0.1:${Port}:8000" `
        --env "DATABASE_URL=sqlite:////tmp/ecommerce-api-smoke.db" `
        --env "ADMIN_TOKEN=$adminToken" `
        --env "SERVICE_NAME=ecommerce-api-isolated-smoke" `
        ecommerce-product-order-api:local | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not start the isolated API container."
    }
    $started = $true

    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        try {
            $health = Invoke-RestMethod -Uri "$baseUrl/health/ready" -TimeoutSec 3
            if ($health.status -eq "ready") {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Seconds 2
        }
        if (-not $ready) {
            Start-Sleep -Seconds 2
        }
    }
    if (-not $ready) {
        throw "The isolated API did not become ready within 60 seconds."
    }

    $live = Invoke-RestMethod -Uri "$baseUrl/health/live" -TimeoutSec 5
    Assert-Equal "Isolated liveness" $live.status "ok"
    Assert-Equal "Isolated readiness" $health.status "ready"
    Assert-Equal "Swagger UI" (Get-HttpStatus "$baseUrl/docs") 200
    Assert-Equal "Unauthenticated admin request" (Get-HttpStatus "$baseUrl/api/v1/admin/audit-events") 401

    $adminHeaders = @{ "X-Admin-Token" = $adminToken; "X-Admin-Actor" = "isolated-smoke" }
    Assert-Equal "Authenticated admin request" (Get-HttpStatus "$baseUrl/api/v1/admin/audit-events" -Headers $adminHeaders) 200

    $suffix = [guid]::NewGuid().ToString("N").Substring(0, 12)
    $productBody = @{
        sku = "ISO-$suffix"
        name = "Isolated Smoke Product"
        price = "12.50"
        stock = 5
        category = "verification"
    } | ConvertTo-Json -Compress
    $createdProduct = Invoke-RestMethod -Uri "$baseUrl/api/v1/admin/products" -Method "POST" `
        -Headers $adminHeaders -ContentType "application/json" -Body $productBody -TimeoutSec 10
    $productId = [int]$createdProduct.id
    if (-not $productId) {
        throw "The isolated API did not return a product ID."
    }
    $search = @(Invoke-RestMethod -Uri "$baseUrl/api/v1/products?q=Isolated%20Smoke" -TimeoutSec 5)
    Assert-Equal "Product search result" $search.Count 1
    $detail = Invoke-RestMethod -Uri "$baseUrl/api/v1/products/$productId" -TimeoutSec 5
    Assert-Equal "Product detail SKU" $detail.sku $createdProduct.sku

    $orderBody = @{
        customer_email = "smoke@example.com"
        items = @(@{ product_id = $productId; quantity = 2 })
    } | ConvertTo-Json -Depth 5 -Compress
    $idempotencyKey = "isolated-$suffix-0001"
    $orderHeaders = @{ "Idempotency-Key" = $idempotencyKey }
    $createResponse = Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/api/v1/orders" -Method "POST" `
        -Headers $orderHeaders -ContentType "application/json" -Body $orderBody -TimeoutSec 10
    Assert-Equal "Order creation status" ([int]$createResponse.StatusCode) 201
    $order = $createResponse.Content | ConvertFrom-Json
    $stockAfterCreate = (Invoke-RestMethod -Uri "$baseUrl/api/v1/products/$productId").stock
    Assert-Equal "Stock after order" $stockAfterCreate 3

    $replayResponse = Invoke-WebRequest -UseBasicParsing -Uri "$baseUrl/api/v1/orders" -Method "POST" `
        -Headers $orderHeaders -ContentType "application/json" -Body $orderBody -TimeoutSec 10
    Assert-Equal "Idempotent replay status" ([int]$replayResponse.StatusCode) 201
    $replay = $replayResponse.Content | ConvertFrom-Json
    Assert-Equal "Idempotent order ID" $replay.id $order.id
    $stockAfterReplay = (Invoke-RestMethod -Uri "$baseUrl/api/v1/products/$productId").stock
    Assert-Equal "Stock unchanged after replay" $stockAfterReplay 3

    $differentBody = @{
        customer_email = "smoke@example.com"
        items = @(@{ product_id = $productId; quantity = 1 })
    } | ConvertTo-Json -Depth 5 -Compress
    Assert-Equal "Idempotency key conflict" (Get-HttpStatus "$baseUrl/api/v1/orders" -Method "POST" `
        -Headers $orderHeaders -Body $differentBody) 409
    $invalidBody = '{"customer_email":"not-an-email","items":[]}'
    Assert-Equal "Order validation" (Get-HttpStatus "$baseUrl/api/v1/orders" -Method "POST" `
        -Headers @{ "Idempotency-Key" = "invalid-order-$suffix" } -Body $invalidBody) 422
    Assert-Equal "Order retrieval" (Get-HttpStatus "$baseUrl/api/v1/orders/$($order.id)") 200

    Write-Output "PASS Isolated API smoke suite (SQLite tmpfs; no assignment database used)"
}
finally {
    if ($started) {
        Write-Output "--- isolated API container logs (request metadata only) ---"
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & docker logs $containerName 2>&1 | ForEach-Object { Write-Output "$_" }
        }
        catch {
            Write-Output "WARN Could not capture isolated API container logs"
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        & docker stop --timeout 10 $containerName | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "The isolated API container did not stop cleanly; inspect the container '$containerName'."
        }
    }
    Pop-Location
}
