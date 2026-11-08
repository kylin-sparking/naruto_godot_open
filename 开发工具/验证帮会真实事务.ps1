param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$clientRoot = Split-Path -Parent $PSScriptRoot
$fixtureProject = Join-Path $workspaceRoot ".tmp_check\GuildFixture\GuildFixture.csproj"
$testRoot = "res://" + [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5rWL6K+V"))
$testName = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("5biu5Lya55yf5a6e5LqL5Yqh5Zue5b2S5rWL6K+VLmdk"))
$testPath = "$testRoot/$testName"

try {
    dotnet run --project $fixtureProject -- setup
    if ($LASTEXITCODE -ne 0) { throw "Guild fixture setup failed." }
    & $Godot --headless --path $clientRoot --script $testPath
    if ($LASTEXITCODE -ne 0) { throw "Guild integration regression failed." }
}
finally {
    dotnet run --project $fixtureProject -- cleanup
    if ($LASTEXITCODE -ne 0) { throw "Guild fixture cleanup failed." }
}
