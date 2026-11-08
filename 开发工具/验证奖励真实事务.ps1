param(
    [string]$Dotnet = "dotnet"
)

$ErrorActionPreference = "Stop"
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$fixture = Join-Path $workspaceRoot ".tmp_check\RewardFixture\RewardFixture.csproj"

& $Dotnet run --project $fixture
if ($LASTEXITCODE -ne 0) {
    throw "Reward transaction fixture failed with exit code $LASTEXITCODE"
}

Write-Host "Reward transaction regression passed."
