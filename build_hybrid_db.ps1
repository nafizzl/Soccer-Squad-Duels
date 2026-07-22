# Script to parse top1000.csv & anothertop1000.txt, match against CSV databases, calculate consensus rank, map bell curve OVR, apply proportional stat scaling, and write CardDatabase.lua.

$topCsvPath = "c:\Users\Nafiz Labib\Soccer-Squad-Duels\top1000.csv"
$topTxtPath = "c:\Users\Nafiz Labib\Soccer-Squad-Duels\anothertop1000.txt"

$fut22Path  = "c:\Users\Nafiz Labib\Soccer-Squad-Duels\fut22players.csv"
$fc26Path   = "c:\Users\Nafiz Labib\Soccer-Squad-Duels\EAFC26-Men.csv"

Write-Host "Loading CSV databases..."
$fut22 = Import-Csv $fut22Path
$fc26  = Import-Csv $fc26Path

# Create a lookup dictionary of all licensed players in our CSVs
$licensedDb = [System.Collections.Generic.Dictionary[string, psobject]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Normalize-Name ([string]$name) {
    if ([string]::IsNullOrWhiteSpace($name)) { return "" }
    $n = $name.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($c in $n.ToCharArray()) {
        $uc = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
        if ($uc -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($c)
        }
    }
    $clean = $sb.ToString().ToLower()
    $clean = $clean -replace '[^a-z0-9\s]', ' '
    $clean = $clean -replace '\s+', ' '
    return $clean.Trim()
}

# Populate from fut22 (Icons and Heroes get highest priority)
foreach ($row in $fut22) {
    $norm = Normalize-Name $row.player_name
    if (-not [string]::IsNullOrWhiteSpace($norm)) {
        $ovr = [int]$row.overall
        if (-not $licensedDb.ContainsKey($norm) -or $ovr -gt $licensedDb[$norm].OVR) {
            $licensedDb[$norm] = [PSCustomObject]@{
                RawName = $row.player_name
                Position = $row.position
                OVR = $ovr
                Pace = [int]$row.pace
                Shooting = [int]$row.shooting
                Passing = [int]$row.passing
                Dribbling = [int]$row.dribbling
                Defending = [int]$row.defending
                Physical = [int]$row.physicality
            }
        }
    }
}

# Populate from FC26
foreach ($row in $fc26) {
    $norm = Normalize-Name $row.Name
    if (-not [string]::IsNullOrWhiteSpace($norm)) {
        $ovr = [int]$row.OVR
        if (-not $licensedDb.ContainsKey($norm) -or $ovr -gt $licensedDb[$norm].OVR) {
            $pac = if ([string]::IsNullOrWhiteSpace($row.PAC)) { [int]$row.'GK Diving' } else { [int]$row.PAC }
            $sho = if ([string]::IsNullOrWhiteSpace($row.SHO)) { [int]$row.'GK Handling' } else { [int]$row.SHO }
            $pas = if ([string]::IsNullOrWhiteSpace($row.PAS)) { [int]$row.'GK Kicking' } else { [int]$row.PAS }
            $dri = if ([string]::IsNullOrWhiteSpace($row.DRI)) { [int]$row.'GK Reflexes' } else { [int]$row.DRI }
            $def = if ([string]::IsNullOrWhiteSpace($row.DEF)) { 50 } else { [int]$row.DEF }
            $phy = if ([string]::IsNullOrWhiteSpace($row.PHY)) { [int]$row.'GK Positioning' } else { [int]$row.PHY }

            $licensedDb[$norm] = [PSCustomObject]@{
                RawName = $row.Name
                Position = $row.Position
                OVR = $ovr
                Pace = $pac
                Shooting = $sho
                Passing = $pas
                Dribbling = $dri
                Defending = $def
                Physical = $phy
            }
        }
    }
}

Write-Host "Total Licensed DB Unique Players: $($licensedDb.Count)"

# Parse top1000.csv
$topCsv = Import-Csv $topCsvPath
$csvRanks = [ordered]@{}
foreach ($row in $topCsv) {
    $rnk = [int]$row.Rnk
    $name = $row.Athlete
    $norm = Normalize-Name $name
    if (-not [string]::IsNullOrWhiteSpace($norm) -and -not $csvRanks.Contains($norm)) {
        $csvRanks[$norm] = @{ Name = $name; Rank = $rnk }
    }
}

# Parse anothertop1000.txt
$txtContent = Get-Content $topTxtPath -Raw
$matches = [regex]::Matches($txtContent, '(\d+)\.([A-Za-z\.\s\-\'\’]+?)(?=\s+\d+\.|\s*$)')
$txtRanks = [ordered]@{}
foreach ($m in $matches) {
    $rnk = [int]$m.Groups[1].Value
    $name = $m.Groups[2].Value.Trim()
    $norm = Normalize-Name $name
    if (-not [string]::IsNullOrWhiteSpace($norm) -and -not $txtRanks.Contains($norm)) {
        $txtRanks[$norm] = @{ Name = $name; Rank = $rnk }
    }
}

Write-Host "Top CSV Player Count: $($csvRanks.Count)"
Write-Host "Top TXT Player Count: $($txtRanks.Count)"

$matchedCandidates = [System.Collections.Generic.List[psobject]]::new()
$usedNorms = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Find-LicensedMatch([string]$normName) {
    if ($licensedDb.ContainsKey($normName)) { return $licensedDb[$normName] }
    
    $tokens = $normName -split ' '
    if ($tokens.Count -gt 1) {
        $lastName = $tokens[-1]
        if ($lastName.Length -gt 3) {
            foreach ($kv in $licensedDb.GetEnumerator()) {
                if ($kv.Key.EndsWith($lastName) -or $kv.Key.StartsWith($tokens[0])) {
                    $dbTokens = $kv.Key -split ' '
                    $overlap = 0
                    foreach ($t in $tokens) { if ($dbTokens -contains $t) { $overlap++ } }
                    if ($overlap -ge 2 -or ($overlap -eq 1 -and $tokens.Count -eq 2 -and $lastName.Length -ge 4)) {
                        return $kv.Value
                    }
                }
            }
        }
    }
    return $null
}

# 1. Match from ranking lists
foreach ($kv in $csvRanks.GetEnumerator()) {
    $norm = $kv.Key
    $rank1 = $kv.Value.Rank
    $rank2 = if ($txtRanks.Contains($norm)) { $txtRanks[$norm].Rank } else { 500 }
    $avgRank = ($rank1 + $rank2) / 2.0

    $match = Find-LicensedMatch $norm
    if ($match -ne $null) {
        $mNorm = Normalize-Name $match.RawName
        if (-not $usedNorms.Contains($mNorm)) {
            [void]$usedNorms.Add($mNorm)
            $matchedCandidates.Add([PSCustomObject]@{
                Name = $match.RawName
                Position = $match.Position
                BaseOVR = $match.OVR
                ConsensusRank = $avgRank
                Pace = $match.Pace
                Shooting = $match.Shooting
                Passing = $match.Passing
                Dribbling = $match.Dribbling
                Defending = $match.Defending
                Physical = $match.Physical
            })
        }
    }
}

Write-Host "Matched from top 1000 lists: $($matchedCandidates.Count)"

# 2. Fill remaining up to 1000 using top rated remaining licensed players
if ($matchedCandidates.Count -lt 1000) {
    $remainingLicensed = $licensedDb.Values | Where-Object { -not $usedNorms.Contains((Normalize-Name $_.RawName)) } | Sort-Object OVR -Descending
    $currentRank = 500.0
    foreach ($rem in $remainingLicensed) {
        if ($matchedCandidates.Count -ge 1000) { break }
        $mNorm = Normalize-Name $rem.RawName
        if (-not $usedNorms.Contains($mNorm)) {
            [void]$usedNorms.Add($mNorm)
            $currentRank += 0.5
            $matchedCandidates.Add([PSCustomObject]@{
                Name = $rem.RawName
                Position = $rem.Position
                BaseOVR = $rem.OVR
                ConsensusRank = $currentRank
                Pace = $rem.Pace
                Shooting = $rem.Shooting
                Passing = $rem.Passing
                Dribbling = $rem.Dribbling
                Defending = $rem.Defending
                Physical = $rem.Physical
            })
        }
    }
}

Write-Host "Total Final Selected Candidates: $($matchedCandidates.Count)"

# Sort matched candidates by ConsensusRank ascending (1 is best)
$final1000 = $matchedCandidates | Sort-Object ConsensusRank

$cardMap = [ordered]@{}
$idSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Scale-Stat([int]$val, [double]$ratio) {
    if ($val -le 0) { return 40 }
    $scaled = [math]::Round($val * $ratio)
    if ($scaled -gt 99) { $scaled = 99 }
    if ($scaled -lt 25) { $scaled = 25 }
    return $scaled
}

for ($i = 0; $i -lt $final1000.Count; $i++) {
    $c = $final1000[$i]
    $rankIdx = $i + 1
    
    $targetOvr = 75
    $rarity = "Bronze"

    if ($rankIdx -le 150) {
        $rarity = "Legend"
        $targetOvr = [math]::Round(99 - (($rankIdx - 1) / 149.0) * 9)
    } elseif ($rankIdx -le 400) {
        $rarity = "Gold"
        $targetOvr = [math]::Round(89 - (($rankIdx - 151) / 249.0) * 6)
    } elseif ($rankIdx -le 700) {
        $rarity = "Silver"
        $targetOvr = [math]::Round(82 - (($rankIdx - 401) / 299.0) * 4)
    } else {
        $rarity = "Bronze"
        $targetOvr = [math]::Round(77 - (($rankIdx - 701) / 299.0) * 2)
    }

    $scaleRatio = if ($c.BaseOVR -gt 0) { $targetOvr / [double]$c.BaseOVR } else { 1.0 }

    $sPace = Scale-Stat $c.Pace $scaleRatio
    $sSho  = Scale-Stat $c.Shooting $scaleRatio
    $sPas  = Scale-Stat $c.Passing $scaleRatio
    $sDri  = Scale-Stat $c.Dribbling $scaleRatio
    $sDef  = Scale-Stat $c.Defending $scaleRatio
    $sPhy  = Scale-Stat $c.Physical $scaleRatio

    $cleanName = ($c.Name -replace '[^a-zA-Z0-9]', '_').ToUpper()
    $cleanName = $cleanName -replace '_+', '_'
    $cleanName = $cleanName.Trim('_')
    if ([string]::IsNullOrWhiteSpace($cleanName)) { $cleanName = "PLAYER" }
    
    $cardId = "${cleanName}_${targetOvr}"
    $suffix = 1
    while ($idSet.Contains($cardId)) {
        $cardId = "${cleanName}_${targetOvr}_${suffix}"
        $suffix++
    }
    [void]$idSet.Add($cardId)

    $escName = $c.Name -replace '\\', '\\' -replace '"', '\"'
    $pos = $c.Position
    if ([string]::IsNullOrWhiteSpace($pos)) { $pos = "CM" }

    $cardMap[$cardId] = @{
        CardID = $cardId
        PlayerIdentity = $escName
        Name = $escName
        Position = $pos
        OVR = $targetOvr
        Rarity = $rarity
        Pace = $sPace
        Shooting = $sSho
        Passing = $sPas
        Dribbling = $sDri
        Defending = $sDef
        Physical = $sPhy
    }
}

# Write CardDatabase.lua
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('-- ReplicatedStorage/Data/CardDatabase.lua')
$lines.Add('export type CardRarity = "Bronze" | "Silver" | "Gold" | "Legend"')
$lines.Add('export type CardPosition = "GK" | "CB" | "LB" | "RB" | "LWB" | "RWB" | "CDM" | "CM" | "CAM" | "LM" | "RM" | "LW" | "RW" | "ST" | "CF"')
$lines.Add('')
$lines.Add('export type CardData = {')
$lines.Add('	CardID: string,')
$lines.Add('	PlayerIdentity: string,')
$lines.Add('	Name: string,')
$lines.Add('	Position: CardPosition,')
$lines.Add('	OVR: number,')
$lines.Add('	Rarity: CardRarity,')
$lines.Add('	Stats: {')
$lines.Add('		Pace: number,')
$lines.Add('		Shooting: number,')
$lines.Add('		Passing: number,')
$lines.Add('		Dribbling: number,')
$lines.Add('		Defending: number,')
$lines.Add('		Physical: number,')
$lines.Add('	},')
$lines.Add('	RigConfig: {')
$lines.Add('		BodyColorPalette: {number},')
$lines.Add('		AccessoryIds: {number},')
$lines.Add('		FaceDecalId: number,')
$lines.Add('	},')
$lines.Add('}')
$lines.Add('')
$lines.Add('local CardDatabase: {[string]: CardData} = {')

foreach ($kv in $cardMap.GetEnumerator()) {
    $cd = $kv.Value
    $lines.Add("	[`"$($cd.CardID)`"] = {")
    $lines.Add("		CardID = `"$($cd.CardID)`",")
    $lines.Add("		PlayerIdentity = `"$($cd.PlayerIdentity)`",")
    $lines.Add("		Name = `"$($cd.Name)`",")
    $lines.Add("		Position = `"$($cd.Position)`",")
    $lines.Add("		OVR = $($cd.OVR),")
    $lines.Add("		Rarity = `"$($cd.Rarity)`",")
    $lines.Add('		Stats = {')
    $lines.Add("			Pace = $($cd.Pace),")
    $lines.Add("			Shooting = $($cd.Shooting),")
    $lines.Add("			Passing = $($cd.Passing),")
    $lines.Add("			Dribbling = $($cd.Dribbling),")
    $lines.Add("			Defending = $($cd.Defending),")
    $lines.Add("			Physical = $($cd.Physical),")
    $lines.Add('		},')
    $lines.Add('		RigConfig = {')
    $lines.Add('			BodyColorPalette = {1, 2, 3},')
    $lines.Add('			AccessoryIds = {},')
    $lines.Add('			FaceDecalId = 0,')
    $lines.Add('		},')
    $lines.Add('	},')
}

$lines.Add('}')
$lines.Add('')
$lines.Add('return CardDatabase')

$outPath = "c:\Users\Nafiz Labib\Soccer-Squad-Duels\ReplicatedStorage\Data\CardDatabase.lua"
[System.IO.File]::WriteAllLines($outPath, $lines, [System.Text.Encoding]::UTF8)
Write-Host "Successfully wrote CardDatabase.lua with $($cardMap.Count) cards!"
