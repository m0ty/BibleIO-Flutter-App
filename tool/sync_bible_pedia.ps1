[CmdletBinding()]
param(
    [string] $SourcePath = (
        Join-Path $PSScriptRoot '..\..\bible-io-pedia-dart\data\encyclopedia.bundle.json'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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

if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    throw "Bible Pedia bundle was not found: $SourcePath"
}

$resolvedSource = [System.IO.Path]::GetFullPath(
    (Resolve-Path -LiteralPath $SourcePath).ProviderPath
)
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

New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
Copy-Item -LiteralPath $resolvedSource -Destination $destinationPath -Force

$syncedBundle = Get-Item -LiteralPath $destinationPath
$sourceHash = (Get-FileHash -LiteralPath $resolvedSource -Algorithm SHA256).Hash
$destinationHash = (
    Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
).Hash
if ($sourceHash -ne $destinationHash) {
    throw 'The synced Bible Pedia bundle failed SHA-256 verification.'
}

$sizeMiB = $syncedBundle.Length / 1MB
Write-Output 'Synced Bible Pedia bundle.'
Write-Output "Source:      $resolvedSource"
Write-Output "Destination: $destinationPath"
Write-Output ('Size:        {0:N0} bytes ({1:N2} MiB)' -f $syncedBundle.Length, $sizeMiB)
Write-Output "SHA-256:     $destinationHash"
