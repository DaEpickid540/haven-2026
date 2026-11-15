# build
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$out = Join-Path $root "build\web"

if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null

godot --headless --path $root --export-release "Deathbounce" $out\index.html
if ($LASTEXITCODE -ne 0) { throw "Godot export failed" }

# controller
$pad = Join-Path $root "website-controller"
Copy-Item "$pad\index.html" "$out\controller.html"
Copy-Item "$pad\*.js", "$pad\*.css" $out
New-Item -ItemType Directory -Force "$out\fonts" | Out-Null
Copy-Item "$pad\fonts\*.ttf", "$pad\fonts\OFL.txt" "$out\fonts"

Write-Host "Built $out"
