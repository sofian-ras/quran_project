# fix_dua_audio_urls.ps1
# Reassigns audio URLs in hisn_almuslim.json sequentially (1.mp3, 2.mp3, ...)
# in the order duas appear in the file, skipping duas with no audio.
#
# Why: the JSON has 271 duas with audio spanning URLs 1-297 with 26 gaps,
# causing some duas to point to the wrong audio file on hisnmuslim.com.
# Sequential reassignment maps each dua to its correct positional audio.
#
# Uses direct regex replacement to avoid JSON parse/serialize round-trip issues.

param(
    [string]$InputFile  = "$PSScriptRoot\..\assets\data\hisn_almuslim.json",
    [string]$OutputFile = "$PSScriptRoot\..\assets\data\hisn_almuslim.json",
    [string]$BaseUrl    = "http://www.hisnmuslim.com/audio/ar/"
)

$ErrorActionPreference = "Stop"

Write-Host "Reading $InputFile ..."
$text = [System.IO.File]::ReadAllText($InputFile, [System.Text.Encoding]::UTF8)

# Pattern: matches a non-empty arabic_recitation value (ends with .mp3)
$pattern = '"arabic_recitation":\s*"(http://www\.hisnmuslim\.com/audio/ar/\d+\.mp3)"'

$counter = 0
$changed = 0

$result = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    $pattern,
    [System.Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $script:counter++
        $newUrl  = "${BaseUrl}${script:counter}.mp3"
        $oldUrl  = $match.Groups[1].Value
        if ($oldUrl -ne $newUrl) { $script:changed++ }
        return '"arabic_recitation": "' + $newUrl + '"'
    }
)

Write-Host "Total URLs reecrites   : $counter"
Write-Host "URLs effectivement changees : $changed"

if ($counter -eq 0) {
    Write-Host "ERREUR: aucune URL trouvee. Verifiez le pattern." -ForegroundColor Red
    exit 1
}

[System.IO.File]::WriteAllText($OutputFile, $result, [System.Text.UTF8Encoding]::new($false))
Write-Host "Ecrit dans $OutputFile"
