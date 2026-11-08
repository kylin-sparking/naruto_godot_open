param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$clientRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $clientRoot
$fixtureProject = Join-Path $workspaceRoot ".tmp_check\PetFixture"
$testPath = "res://" + [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5rWL6K+VL+WuoOeJqeecn+WunuS6i+WKoeWbnuW9kua1i+ivlS5nZA=="))

try {
    & dotnet run --project $fixtureProject -c Release -- setup
    if ($LASTEXITCODE -ne 0) { throw "Failed to prepare pet transaction fixture." }
    & $Godot --headless --path $clientRoot --script $testPath
    if ($LASTEXITCODE -ne 0) { throw "Pet transaction integration regression failed." }
}
finally {
    & dotnet run --project $fixtureProject -c Release -- cleanup
    if ($LASTEXITCODE -ne 0) { Write-Error "Pet fixture cleanup failed." }
}
