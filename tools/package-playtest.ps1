param([string]$OutputDirectory = 'build/limited-playtest')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$repoRoot = (Get-Location).Path
$buildRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'build'))
$outputRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot $OutputDirectory))
if (-not $outputRoot.StartsWith($buildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputDirectory must be a child directory of this repository build directory.'
}
# Do not follow junctions/symlinks out of the intended artifact directory.
$ancestor = $outputRoot
while ($ancestor -and $ancestor -ne $repoRoot) {
    if (Test-Path -LiteralPath $ancestor) {
        if ((Get-Item -LiteralPath $ancestor).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Artifact path contains a junction or symbolic link: $ancestor"
        }
    }
    $ancestor = Split-Path $ancestor -Parent
}
$OutputDirectory = $outputRoot
foreach ($artifactName in @('LimitedPlaytest.rbxlx', 'manifest.json', 'LIMITED_PLAYTEST.md', 'PLAYTEST_EVIDENCE.md', 'package-playtest.ps1')) {
    $artifactPath = Join-Path $outputRoot $artifactName
    if (Test-Path -LiteralPath $artifactPath) {
        if ((Get-Item -LiteralPath $artifactPath).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Artifact target is a symbolic link: $artifactPath"
        }
    }
}
function CheckExit([string]$Step) {
    if ($LASTEXITCODE -ne 0) { throw "$Step failed ($LASTEXITCODE)" }
}
$revision = git rev-parse HEAD
CheckExit 'Git revision'
$dirty = git status --porcelain
CheckExit 'Git status'
if ($dirty) { throw 'Commit or preserve working changes before packaging an identifiable checkpoint.' }
$ignoredSources = git ls-files --others --ignored --exclude-standard -- src
CheckExit 'Ignored source check'
if ($ignoredSources) { throw 'Ignored files in src could change the Rojo build; preserve them outside src before packaging.' }
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$env:ROBLOX_DEFS = (Resolve-Path '.tools/globalTypes.d.luau').Path
python -X utf8 tests/tools/bundle.py
CheckExit 'Headless bundle'
& '.tools/luau.exe' tests/preflight.luau
CheckExit 'Core-playtest preflight'
$place = Join-Path $OutputDirectory 'LimitedPlaytest.rbxlx'
rojo build default.project.json -o $place
CheckExit 'Rojo build'
$rojoVersion = (rojo --version | Out-String).Trim()
CheckExit 'Rojo version'
$pythonVersion = (python --version | Out-String).Trim()
CheckExit 'Python version'
$luauVersion = (Get-FileHash -LiteralPath '.tools/luau.exe' -Algorithm SHA256).Hash
$configText = Get-Content -LiteralPath 'src/shared/Config/init.luau' -Raw
$dataStoreMatch = [regex]::Match($configText, 'DATASTORE_NAME\s*=\s*"([^"]+)"')
if (-not $dataStoreMatch.Success) { throw 'Cannot identify DATASTORE_NAME for the manifest.' }
$finalRevision = git rev-parse HEAD
CheckExit 'Final Git revision'
$finalDirty = git status --porcelain
CheckExit 'Final Git status'
if ($finalDirty -or $finalRevision -ne $revision) { throw 'Source changed during packaging; discard this candidate and retry from a clean checkpoint.' }
$manifest = [ordered]@{
    sourceRevision = $revision.Trim()
    createdUtc = [DateTime]::UtcNow.ToString('o')
    project = 'default.project.json'
    placeSha256 = (Get-FileHash -LiteralPath $place -Algorithm SHA256).Hash
    purpose = 'Local candidate; publication and audience changes require explicit owner authorization'
    configuration = 'Core loop; 8 passes, 6 products, 10 badges, group bonus and music/ambience unconfigured'
    evidence = 'See docs/PLAYTEST_EVIDENCE.md; build success does not close live release gates'
    rojoVersion = $rojoVersion
    pythonVersion = $pythonVersion
    luauExecutableSha256 = $luauVersion
    robloxDefinitionsSha256 = (Get-FileHash -LiteralPath $env:ROBLOX_DEFS -Algorithm SHA256).Hash
    projectSha256 = (Get-FileHash -LiteralPath 'default.project.json' -Algorithm SHA256).Hash
    dataStoreName = $dataStoreMatch.Groups[1].Value
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $OutputDirectory 'manifest.json') -Encoding utf8
Copy-Item -LiteralPath 'docs/LIMITED_PLAYTEST.md','docs/PLAYTEST_EVIDENCE.md' -Destination $OutputDirectory
Copy-Item -LiteralPath 'tools/package-playtest.ps1' -Destination $OutputDirectory
Write-Output "Local playtest package: $OutputDirectory ($revision)"
