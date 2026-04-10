param(
    [string]$TargetDir = "mods/deathmatch/resources/[vrp]",
    [string]$RepoUrl = "https://github.com/eXo-OpenSource/mta-gamemode.git"
)

$ErrorActionPreference = "Stop"
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) ("exo-vrp-" + [System.Guid]::NewGuid().ToString("N"))
$srcDir = Join-Path $workDir "src"

try {
    New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/eXo-OpenSource/mta-gamemode/releases/latest"
    $tag = $release.tag_name

    if ([string]::IsNullOrWhiteSpace($tag)) {
        throw "Unable to determine latest eXo release tag."
    }

    git clone --depth 1 --branch $tag $RepoUrl $srcDir
    Push-Location $srcDir
    python build/buildscript.py --branch $tag
    Pop-Location

    if (Test-Path $TargetDir) {
        Remove-Item -Recurse -Force $TargetDir
    }

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Copy-Item -Recurse -Force (Join-Path $srcDir "*") $TargetDir

    $gitDir = Join-Path $TargetDir ".git"
    if (Test-Path $gitDir) {
        Remove-Item -Recurse -Force $gitDir
    }

    Write-Host ("Installed eXo release {0} into {1}" -f $tag, $TargetDir)
}
finally {
    if (Test-Path $workDir) {
        Remove-Item -Recurse -Force $workDir
    }
}
