param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$clientRoot = Split-Path -Parent $PSScriptRoot
$fixtureProject = Join-Path $workspaceRoot ".tmp_check\SocialFixture\SocialFixture.csproj"
$testRoot = "res://" + [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5rWL6K+V"))
$testName = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("56S+5Lqk55yf5a6e5LqL5Yqh5Zue5b2S5rWL6K+VLmdk"))
$testPath = "$testRoot/$testName"

try {
    dotnet run --project $fixtureProject -- setup
    if ($LASTEXITCODE -ne 0) { throw "Social fixture setup failed." }
    $statePath = Join-Path (Split-Path -Parent $fixtureProject) "bin\Debug\net8.0\social-fixture-state.json"
    $env:NW_SOCIAL_PEER_ID = [string](Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json).PeerId
    & $Godot --headless --path $clientRoot --script $testPath
    if ($LASTEXITCODE -ne 0) { throw "Social integration regression failed." }
}
finally {
    Remove-Item Env:NW_SOCIAL_PEER_ID -ErrorAction SilentlyContinue
    dotnet run --project $fixtureProject -- cleanup
    if ($LASTEXITCODE -ne 0) { throw "Social fixture cleanup failed." }
}
