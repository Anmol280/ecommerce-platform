param(
    [string]$DbUser = "ecommerce",
    [string]$DbName = "ecommerce",
    [string]$BackupDirectory = ".\backups"
)

$ErrorActionPreference = "Stop"
$null = New-Item -ItemType Directory -Force -Path $BackupDirectory
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupPath = Join-Path $BackupDirectory "ecommerce-$stamp.dump"
$containerPath = "/tmp/ecommerce-backup-$stamp.dump"

docker compose exec -T db pg_dump -U $DbUser -d $DbName -Fc -f $containerPath
if ($LASTEXITCODE -ne 0) { throw "pg_dump failed with exit code $LASTEXITCODE" }
docker compose cp "db:$containerPath" $backupPath
if ($LASTEXITCODE -ne 0) { throw "Copying the backup out of the database container failed" }
docker compose exec -T db rm -f $containerPath
if ($LASTEXITCODE -ne 0) { Write-Warning "Backup succeeded, but the temporary container copy could not be removed." }
Write-Output "Backup created: $((Resolve-Path $backupPath).Path)"
