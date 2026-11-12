$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$workId = [guid]::NewGuid().ToString("N")
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ecommerce-recovery-$workId"
$composePath = Join-Path $testRoot "compose.yaml"
$backupDirectory = Join-Path $testRoot "dumps"
$projectName = "ecommerce-recovery-$($workId.Substring(0, 12))"
$environmentNames = @("COMPOSE_FILE", "COMPOSE_PROJECT_NAME", "RECOVERY_TEST_DB_PASSWORD")
$previousEnvironment = @{}
$started = $false

foreach ($name in $environmentNames) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
}

Push-Location $projectRoot
try {
    $randomBytes = New-Object byte[] 32
    $randomGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $randomGenerator.GetBytes($randomBytes)
        $testPassword = [Convert]::ToBase64String($randomBytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
    }
    finally {
        $randomGenerator.Dispose()
    }

    $composeText = @'
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ecommerce
      POSTGRES_USER: ecommerce
      POSTGRES_PASSWORD: ${RECOVERY_TEST_DB_PASSWORD:?}
    tmpfs:
      - /var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 2s
      timeout: 2s
      retries: 20
      start_period: 3s
'@
    $null = New-Item -ItemType Directory -Force -Path $testRoot
    $null = New-Item -ItemType Directory -Force -Path $backupDirectory
    [System.IO.File]::WriteAllText($composePath, $composeText, [System.Text.UTF8Encoding]::new($false))

    [Environment]::SetEnvironmentVariable("COMPOSE_FILE", $composePath, "Process")
    [Environment]::SetEnvironmentVariable("COMPOSE_PROJECT_NAME", $projectName, "Process")
    [Environment]::SetEnvironmentVariable("RECOVERY_TEST_DB_PASSWORD", $testPassword, "Process")

    & docker compose up -d db
    if ($LASTEXITCODE -ne 0) {
        throw "Could not start the isolated PostgreSQL service."
    }
    $started = $true

    $containerId = (& docker compose ps -q db | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $containerId) {
        throw "Could not identify the isolated PostgreSQL container."
    }
    $tmpfsRaw = & docker inspect --format '{{json .HostConfig.Tmpfs}}' $containerId
    $inspectCode = $LASTEXITCODE
    if ($inspectCode -ne 0) {
        throw "Could not inspect the isolated PostgreSQL tmpfs configuration."
    }
    $tmpfsJson = ($tmpfsRaw | Out-String).Trim()
    $tmpfsConfig = $tmpfsJson | ConvertFrom-Json
    $dataTmpfs = $tmpfsConfig.PSObject.Properties["/var/lib/postgresql/data"]

    $mountsRaw = & docker inspect --format '{{json .Mounts}}' $containerId
    $inspectCode = $LASTEXITCODE
    if ($inspectCode -ne 0) {
        throw "Could not verify isolated PostgreSQL mounts."
    }
    $mounts = @(($mountsRaw | ConvertFrom-Json) | Where-Object { $_.Destination -eq "/var/lib/postgresql/data" })
    if (-not $dataTmpfs -or $mounts.Count -gt 0) {
        throw "Refusing to continue: the isolated database data directory is not mounted as tmpfs."
    }
    Write-Output "PASS Isolated PostgreSQL storage verified as tmpfs"

    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        $health = (& docker inspect --format '{{.State.Health.Status}}' $containerId | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $health -eq "healthy") {
            $ready = $true
            break
        }
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        throw "The isolated PostgreSQL service did not become healthy within 80 seconds."
    }
    Write-Output "PASS Isolated PostgreSQL readiness"

    & docker compose exec -T db psql -v ON_ERROR_STOP=1 -U ecommerce -d ecommerce `
        -c "CREATE TABLE restore_probe (id integer PRIMARY KEY, marker text NOT NULL); INSERT INTO restore_probe VALUES (1, 'before_restore');"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not initialize the synthetic recovery fixture."
    }

    $backupScript = Join-Path $PSScriptRoot "backup.ps1"
    & $backupScript -DbUser ecommerce -DbName ecommerce -BackupDirectory $backupDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "The isolated backup command failed."
    }
    $backupFile = Get-ChildItem -LiteralPath $backupDirectory -Filter "*.dump" | Select-Object -First 1
    if (-not $backupFile) {
        throw "The backup helper did not create a dump file."
    }
    Write-Output "PASS Custom-format backup created"

    & docker compose exec -T db psql -v ON_ERROR_STOP=1 -U ecommerce -d ecommerce `
        -c "UPDATE restore_probe SET marker='after_change' WHERE id=1;"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not change the synthetic fixture before restore."
    }

    $restoreScript = Join-Path $PSScriptRoot "restore.ps1"
    & $restoreScript -BackupPath $backupFile.FullName -DbUser ecommerce -DbName ecommerce -ConfirmRestore
    if ($LASTEXITCODE -ne 0) {
        throw "The isolated restore command failed."
    }
    $restoredValue = (& docker compose exec -T db psql -v ON_ERROR_STOP=1 -U ecommerce -d ecommerce `
        -At -c "SELECT marker FROM restore_probe WHERE id=1;" | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $restoredValue -ne "before_restore") {
        throw "The synthetic marker did not match the backup after restore."
    }
    Write-Output "PASS Restore recovered the expected pre-change synthetic marker"
    Write-Output "PASS Backup/restore rehearsal completed without using the assignment database"
}
finally {
    if ($started) {
        & docker compose down
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Could not stop the isolated recovery test cleanly; project '$projectName' is separate from the assignment stack."
        }
    }
    foreach ($name in $environmentNames) {
        [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], "Process")
    }
    Pop-Location
}
