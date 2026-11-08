param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$clientRoot = Split-Path -Parent $PSScriptRoot
$fixtureProject = Join-Path $workspaceRoot ".tmp_check\LegacyOnlineFixture\LegacyOnlineFixture.csproj"
$testRoot = "res://" + [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5rWL6K+V"))
$testName = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5Lyg5om/5Zyo57q/5Zue5b2S5rWL6K+VLmdk"))
$testPath = "$testRoot/$testName"

try {
    dotnet run --project $fixtureProject -- setup
    if ($LASTEXITCODE -ne 0) { throw "Legacy online fixture setup failed." }
    $statePath = Join-Path (Split-Path -Parent $fixtureProject) "bin\Debug\net8.0\legacy-online-fixture-state.json"
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $env:NW_LEGACY_MAIN_ID = [string]$state.MainId
    $env:NW_LEGACY_PEER_ID = [string]$state.PeerId
    $env:NW_LEGACY_FUSION_FIRST_SLOT = [string]$state.FusionFirstSlot
    $env:NW_LEGACY_FUSION_SECOND_SLOT = [string]$state.FusionSecondSlot
    & $Godot --headless --path $clientRoot --script $testPath
    if ($LASTEXITCODE -ne 0) { throw "Legacy online integration regression failed." }
}
finally {
    Remove-Item Env:NW_LEGACY_MAIN_ID -ErrorAction SilentlyContinue
    Remove-Item Env:NW_LEGACY_PEER_ID -ErrorAction SilentlyContinue
    Remove-Item Env:NW_LEGACY_FUSION_FIRST_SLOT -ErrorAction SilentlyContinue
    Remove-Item Env:NW_LEGACY_FUSION_SECOND_SLOT -ErrorAction SilentlyContinue
    dotnet run --project $fixtureProject -- cleanup
    if ($LASTEXITCODE -ne 0) { throw "Legacy online fixture cleanup failed." }
}
