# tools/generate_reciters_mapping.ps1
# Génère un JSON complet name+asset+server+id à partir de mp3quran + ton mapping local

$ErrorActionPreference = "Stop"

function NormName([string]$s) {
  return ($s.ToLower() -replace '\s+', ' ').Trim()
}

$mappingPath = "assets/data/reciters_mapping.json"
$outPath     = "assets/data/reciters_mapping.generated.json"

if (!(Test-Path $mappingPath)) {
  throw "Fichier introuvable: $mappingPath"
}

# 1) Charger ton mapping local (name + asset)
$mapping = Get-Content $mappingPath -Raw | ConvertFrom-Json

# 2) Appeler l'API mp3quran pour récupérer id + server (moshaf[0].server)
$apiUrl = "https://mp3quran.net/api/v3/reciters?language=fr"
$api = Invoke-RestMethod -Uri $apiUrl -Method GET

$recitersApi = $api.reciters

# 3) Construire un dictionnaire: normalizedName -> {id, server, name}
$apiByName = @{}
foreach ($r in $recitersApi) {
  $name = [string]$r.name
  if ([string]::IsNullOrWhiteSpace($name)) { continue }

  $moshaf = $r.moshaf
  if ($null -eq $moshaf -or $moshaf.Count -eq 0) { continue }

  $server = [string]$moshaf[0].server
  if ([string]::IsNullOrWhiteSpace($server)) { continue }

  $id = [string]$r.id
  $apiByName[(NormName $name)] = @{
    id = $id
    server = $server
    name = $name
  }
}

# 4) Fusion: ton mapping -> ajoute id + server si trouvé
$out = @()
foreach ($m in $mapping) {
  $localName = [string]$m.name
  $asset     = [string]$m.asset

  if ([string]::IsNullOrWhiteSpace($localName)) { continue }

  $key = NormName $localName

  $id = ""
  $server = ""

  if ($apiByName.ContainsKey($key)) {
    $id = $apiByName[$key].id
    $server = $apiByName[$key].server
  }

  $out += [PSCustomObject]@{
    id = $id
    name = $localName
    server = $server
    asset = $asset
    # champs "compat" au cas où ton modèle lit encore suras/letter
    suras = ""
    letter = ""
  }
}

# 5) Écrire le fichier généré
$out | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $outPath

Write-Host "OK -> Généré: $outPath"
Write-Host "Ensuite, remplace $mappingPath par ce fichier si tout est bon."
