param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,
    [string]$DbUser = "ecommerce",
    [string]$DbName = "ecommerce",
    [switch]$ConfirmRestore
)

$ErrorActionPreference = "Stop"
if (-not $ConfirmRestore) {
    throw "Restore replaces matching database objects. Re-run with -ConfirmRestore after choosing a verified backup."
}
$sourcePath = (Resolve-Path -LiteralPath $BackupPath).Path
$fileName = [System.IO.Path]::GetFileName($sourcePath)
$containerPath = "/tmp/$fileName"

docker compose cp $sourcePath "db:$containerPath"
if ($LASTEXITCODE -ne 0) { throw "Copying the backup into the database container failed" }
docker compose exec -T db pg_restore --exit-on-error --clean --if-exists --no-owner -U $DbUser -d $DbName $containerPath
$restoreExitCode = $LASTEXITCODE
docker compose exec -T db rm -f $containerPath
if ($restoreExitCode -ne 0) { throw "pg_restore failed with exit code $restoreExitCode" }
Write-Output "Restore completed from: $sourcePath"
