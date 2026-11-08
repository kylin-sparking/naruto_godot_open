param(
    [string]$Godot = "godot"
)

$ErrorActionPreference = "Stop"
$clientRoot = Split-Path -Parent $PSScriptRoot
$scriptResource = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String("cmVzOi8v5rWL6K+VL+WlluWKseWcqOe6v+afpeivouWbnuW9kua1i+ivlS5nZA=="))
& $Godot --headless --path $clientRoot --script $scriptResource
if ($LASTEXITCODE -ne 0) {
    throw "Online reward query regression failed with exit code $LASTEXITCODE"
}
