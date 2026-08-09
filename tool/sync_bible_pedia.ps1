[CmdletBinding()]
param(
    [string] $DataPath,
    [string] $DartExecutable = 'dart'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DataPath)) {
    $DataPath = Join-Path `
        $PSScriptRoot `
        '..\..\bible-io-pedia-dart\data'
}

$appRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$assetsRoot = [System.IO.Path]::GetFullPath((Join-Path $appRoot 'assets'))
$destinationDirectory = [System.IO.Path]::GetFullPath(
    (Join-Path $assetsRoot 'bible_pedia')
)
$destinationPath = [System.IO.Path]::GetFullPath(
    (Join-Path $destinationDirectory 'encyclopedia.bundle.json')
)
$assetsPrefix = $assetsRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar

if (-not $destinationPath.StartsWith(
    $assetsPrefix,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to write outside the app assets directory: $destinationPath"
}

if (-not (Test-Path -LiteralPath $DataPath -PathType Container)) {
    throw "Bible Pedia data directory was not found: $DataPath"
}

$sourceDirectory = [System.IO.Path]::GetFullPath(
    (Resolve-Path -LiteralPath $DataPath).ProviderPath
)
$resolvedSource = [System.IO.Path]::GetFullPath(
    (Join-Path $sourceDirectory 'encyclopedia.bundle.json')
)
if (-not (Test-Path -LiteralPath $resolvedSource -PathType Leaf)) {
    throw "Bible Pedia bundle was not found: $resolvedSource"
}
$sourceImagesDirectory = Join-Path $sourceDirectory 'images'
if (Test-Path -LiteralPath $sourceImagesDirectory -PathType Container) {
    $sourceImage = Get-ChildItem `
        -LiteralPath $sourceImagesDirectory `
        -Recurse `
        -File | Select-Object -First 1
    if ($null -ne $sourceImage) {
        throw (
            'Bible Pedia images are not yet supported by this app asset layout. ' +
            'Add image rendering and explicit Flutter asset declarations before syncing.'
        )
    }
}
if ([string]::Equals(
    $resolvedSource,
    $destinationPath,
    [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw 'The source and destination Bible Pedia bundles must be different files.'
}

if (-not (Test-Path -LiteralPath $assetsRoot -PathType Container)) {
    throw "The app assets directory does not exist: $assetsRoot"
}

foreach ($directory in @($assetsRoot, $destinationDirectory)) {
    if (Test-Path -LiteralPath $directory) {
        $directoryItem = Get-Item -LiteralPath $directory -Force
        if (
            ($directoryItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        ) {
            throw "Refusing to write through a symbolic link or junction: $directory"
        }
    }
}

if (Test-Path -LiteralPath $destinationPath) {
    $destinationItem = Get-Item -LiteralPath $destinationPath -Force
    if (
        ($destinationItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    ) {
        throw "Refusing to replace a symbolic link: $destinationPath"
    }
}

$dartCommand = Get-Command $DartExecutable -ErrorAction SilentlyContinue
if ($null -eq $dartCommand) {
    throw "Dart executable was not found: $DartExecutable"
}
$resolvedDartExecutable = $dartCommand.Source
if ([System.IO.Path]::GetExtension($resolvedDartExecutable) -eq '.bat') {
    $flutterDartExecutable = [System.IO.Path]::GetFullPath(
        (Join-Path `
            ([System.IO.Path]::GetDirectoryName($resolvedDartExecutable)) `
            'cache\dart-sdk\bin\dart.exe')
    )
    if (Test-Path -LiteralPath $flutterDartExecutable -PathType Leaf) {
        $resolvedDartExecutable = $flutterDartExecutable
    }
}

Push-Location $appRoot
try {
    & $resolvedDartExecutable run bible_pedia_dart export `
        --data $sourceDirectory `
        --output $destinationDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Bible Pedia runtime export failed with exit code $LASTEXITCODE."
    }

    & $resolvedDartExecutable run bible_pedia_dart verify `
        --runtime $destinationDirectory
    if ($LASTEXITCODE -ne 0) {
        throw "Bible Pedia runtime verification failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$syncedBundle = Get-Item -LiteralPath $destinationPath
$destinationHash = (
    Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
).Hash
$sizeMiB = $syncedBundle.Length / 1MB
Write-Output 'Synced and verified Bible Pedia runtime artifact.'
Write-Output "Source data: $sourceDirectory"
Write-Output "Destination: $destinationDirectory"
Write-Output ('Bundle size: {0:N0} bytes ({1:N2} MiB)' -f $syncedBundle.Length, $sizeMiB)
Write-Output "Bundle hash: $destinationHash"
