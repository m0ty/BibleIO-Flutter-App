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
$pubspecPath = [System.IO.Path]::GetFullPath((Join-Path $appRoot 'pubspec.yaml'))
$assetBlockStart = '    # BEGIN GENERATED BIBLE PEDIA RUNTIME ASSETS'
$assetBlockEnd = '    # END GENERATED BIBLE PEDIA RUNTIME ASSETS'
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
if (-not (Test-Path -LiteralPath $pubspecPath -PathType Leaf)) {
    throw "The Flutter pubspec was not found: $pubspecPath"
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

$pubspecItem = Get-Item -LiteralPath $pubspecPath -Force
if (
    ($pubspecItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
) {
    throw "Refusing to replace a symbolic link: $pubspecPath"
}

$pubspecText = [System.IO.File]::ReadAllText($pubspecPath)
$assetBlockStartIndex = $pubspecText.IndexOf(
    $assetBlockStart,
    [System.StringComparison]::Ordinal
)
if ($assetBlockStartIndex -lt 0) {
    throw "The generated Bible Pedia asset block is missing from $pubspecPath"
}
if ($pubspecText.IndexOf(
    $assetBlockStart,
    $assetBlockStartIndex + $assetBlockStart.Length,
    [System.StringComparison]::Ordinal
) -ge 0) {
    throw "The generated Bible Pedia asset block appears more than once in $pubspecPath"
}
$assetBlockEndIndex = $pubspecText.IndexOf(
    $assetBlockEnd,
    $assetBlockStartIndex + $assetBlockStart.Length,
    [System.StringComparison]::Ordinal
)
if ($assetBlockEndIndex -lt 0) {
    throw "The generated Bible Pedia asset block is incomplete in $pubspecPath"
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

$appPrefix = $appRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
) + [System.IO.Path]::DirectorySeparatorChar
$runtimeAssetPaths = @(
    foreach ($runtimeFile in Get-ChildItem `
        -LiteralPath $destinationDirectory `
        -Recurse `
        -Force `
        -File) {
        if (
            ($runtimeFile.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
        ) {
            throw "Refusing to declare a symbolic link as an asset: $($runtimeFile.FullName)"
        }
        $runtimePath = [System.IO.Path]::GetFullPath($runtimeFile.FullName)
        if (-not $runtimePath.StartsWith(
            $appPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Refusing to declare an asset outside the app directory: $runtimePath"
        }
        $runtimePath.Substring($appPrefix.Length).Replace('\', '/')
    }
) | Sort-Object -Unique

if ($runtimeAssetPaths.Count -eq 0) {
    throw "The Bible Pedia runtime artifact contains no files: $destinationDirectory"
}

$lineEnding = if ($pubspecText.Contains("`r`n")) { "`r`n" } else { "`n" }
$generatedAssetLines = @($assetBlockStart)
foreach ($runtimeAssetPath in $runtimeAssetPaths) {
    $escapedAssetPath = $runtimeAssetPath.Replace("'", "''")
    $generatedAssetLines += "    - '$escapedAssetPath'"
}
$generatedAssetLines += $assetBlockEnd
$generatedAssetBlock = $generatedAssetLines -join $lineEnding
$assetBlockEndOffset = $assetBlockEndIndex + $assetBlockEnd.Length
$updatedPubspec = $pubspecText.Substring(0, $assetBlockStartIndex) +
    $generatedAssetBlock +
    $pubspecText.Substring($assetBlockEndOffset)
if (-not [string]::Equals(
    $pubspecText,
    $updatedPubspec,
    [System.StringComparison]::Ordinal
)) {
    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        $pubspecPath,
        $updatedPubspec,
        $utf8WithoutBom
    )
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
Write-Output "Declared runtime assets: $($runtimeAssetPaths.Count)"
