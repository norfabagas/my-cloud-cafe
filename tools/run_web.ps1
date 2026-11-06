param(
  [ValidateRange(1024, 65535)][int]$Port = 3030,
  [string]$Config = '.env.local.json',
  [switch]$Release
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
  if (!(Test-Path -LiteralPath $Config)) {
    throw 'Copy .env.example to .env.local.json and fill the existing Supabase public key first.'
  }
  $publicConfig = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
  if (!$publicConfig.SUPABASE_URL -or !$publicConfig.SUPABASE_ANON_KEY) {
    throw 'SUPABASE_URL and SUPABASE_ANON_KEY are required for Google login.'
  }
  $runArgs = @('run', '-d', 'web-server', '--web-hostname=localhost', "--web-port=$Port", "--dart-define-from-file=$Config")
  if ($Release) { $runArgs += '--release' }

  $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
  $sdkRoot = $env:FLUTTER_ROOT
  if (!$sdkRoot -and (Test-Path -LiteralPath '.dart_tool/package_config.json')) {
    $packages = Get-Content -LiteralPath '.dart_tool/package_config.json' -Raw | ConvertFrom-Json
    $flutterPackage = $packages.packages | Where-Object name -eq 'flutter' | Select-Object -First 1
    if ($flutterPackage) {
      $packageUri = [Uri]$flutterPackage.rootUri
      if ($packageUri.IsFile) {
        $projectSdk = Split-Path -Parent (Split-Path -Parent $packageUri.LocalPath.TrimEnd('/','\'))
        if (Test-Path -LiteralPath (Join-Path $projectSdk 'bin/cache/flutter_tools.snapshot')) { $sdkRoot = $projectSdk }
      }
    }
  }
  if (!$sdkRoot -and $flutterCommand) { $sdkRoot = Split-Path -Parent (Split-Path -Parent $flutterCommand.Source) }
  # A populated SDK cache can run directly, avoiding unrelated launcher updates.
  $dartPath = if ($sdkRoot) { Join-Path $sdkRoot 'bin/cache/dart-sdk/bin/dart.exe' }
  $snapshotPath = if ($sdkRoot) { Join-Path $sdkRoot 'bin/cache/flutter_tools.snapshot' }
  if ($dartPath -and (Test-Path -LiteralPath $dartPath) -and (Test-Path -LiteralPath $snapshotPath)) {
    & $dartPath $snapshotPath @runArgs
  } elseif ($flutterCommand) {
    & $flutterCommand.Source @runArgs
  } else {
    throw 'Flutter is unavailable. Add it to PATH or set FLUTTER_ROOT.'
  }
  $runExitCode = $LASTEXITCODE
} finally { Pop-Location }
exit $runExitCode
