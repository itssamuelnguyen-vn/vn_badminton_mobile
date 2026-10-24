# Builds the release APKs and copies them to build\apk with short names stamped with the build time, so several builds
# of the same version stay apart: vnbadminton-<version>-<yyyyMMdd-HHmm>.apk (arm64, for almost every phone) and
# -arm32 / -x86_64 for the others.
# The server address comes from config\dev.json, as with `flutter run`.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

$version = (Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)').Matches[0].Groups[1].Value
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'

flutter build apk --release --split-per-abi --dart-define-from-file=config/dev.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$out = 'build\apk'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$names = @{
  'app-arm64-v8a-release.apk'   = "vnbadminton-$version-$stamp.apk"
  'app-armeabi-v7a-release.apk' = "vnbadminton-$version-$stamp-arm32.apk"
  'app-x86_64-release.apk'      = "vnbadminton-$version-$stamp-x86_64.apk"
}
foreach ($from in $names.Keys) {
  Copy-Item "build\app\outputs\flutter-apk\$from" (Join-Path $out $names[$from]) -Force
}

$api = (Get-Content config\dev.json -Raw | ConvertFrom-Json).API_URL
Write-Host ""
Write-Host "APK: $(Resolve-Path (Join-Path $out "vnbadminton-$version-$stamp.apk"))"
Write-Host "Server: $api"
