# aggregate_coverage.ps1 - union functional coverage across the whole regression.
#
# Each vsim run is independent, so a single test only records the bins IT hit.
# The coverage collector appends every hit bin to coverage_hits.txt (one line
# per hit, across all 97 runs) and (re)writes the full defined-bin list with a
# group tag to coverage_defined.txt.  This script unions the hits and reports
# per-group and overall closure - the REAL suite-level functional coverage.
$ErrorActionPreference = "Stop"
$root = "C:\Users\ritup\Desktop\vikash_projects\vega_framework\ch03_testbench\ahb2apb_bridge_uvmtb"

$hitsFile = Join-Path $root "coverage_hits.txt"
$defFile  = Join-Path $root "coverage_defined.txt"
if (!(Test-Path $hitsFile)) { Write-Error "no $hitsFile - run the regression first" }
if (!(Test-Path $defFile))  { Write-Error "no $defFile - run the regression first" }

# Union of all hit bin keys across every test.
$hit = New-Object System.Collections.Generic.HashSet[string]
Get-Content $hitsFile | ForEach-Object { if ($_.Trim()) { [void]$hit.Add($_.Trim()) } }

# Defined bins, grouped.  Each line: GROUP<TAB>FULLKEY
$groupOrder = @("AHB_TXN","APB_TXN","REGISTER_ACCESS","ERROR_SCENARIOS","AHB_PROTOCOL","APB_PROTOCOL")
$defined = @{}      # group -> list of full keys
$uncovered = @{}    # group -> list of uncovered full keys
foreach ($g in $groupOrder) { $defined[$g] = @(); $uncovered[$g] = @() }

Get-Content $defFile | ForEach-Object {
    $parts = $_ -split "`t"
    if ($parts.Count -eq 2) {
        $g = $parts[0]; $key = $parts[1]
        $defined[$g] += $key
        if (-not $hit.Contains($key)) { $uncovered[$g] += $key }
    }
}

$lines = @()
$lines += "================ FUNCTIONAL COVERAGE - SUITE UNION ================"
$lines += "Aggregated across the full regression suite (union of per-test hits)."
$lines += ""
$lines += ("{0,-18} {1,8}  {2}" -f "GROUP", "CLOSURE", "BINS")
$lines += ("-" * 66)
$totDef = 0; $totHit = 0
foreach ($g in $groupOrder) {
    $d = $defined[$g].Count
    $h = $d - $uncovered[$g].Count
    $totDef += $d; $totHit += $h
    $pct = if ($d -gt 0) { [math]::Round(100.0 * $h / $d, 1) } else { 100.0 }
    $lines += ("{0,-18} {1,7}% {2}" -f $g, $pct, "$h/$d")
}
$lines += ("-" * 66)
$ovPct = if ($totDef -gt 0) { [math]::Round(100.0 * $totHit / $totDef, 1) } else { 100.0 }
$lines += ("{0,-18} {1,7}% {2}" -f "OVERALL", $ovPct, "$totHit/$totDef")
$lines += ""

# List uncovered bins per group (the honest gaps).
foreach ($g in $groupOrder) {
    if ($uncovered[$g].Count -gt 0) {
        $lines += ("UNCOVERED - {0} ({1}):" -f $g, $uncovered[$g].Count)
        foreach ($k in $uncovered[$g]) { $lines += ("    " + $k) }
    }
}
if (($uncovered.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum -eq 0) {
    $lines += "ALL DEFINED BINS COVERED."
}

$out = $lines -join "`r`n"
Write-Output $out
$reportPath = Join-Path $root "coverage_report_measured.txt"
Set-Content -Path $reportPath -Value $out -Encoding ascii
Write-Output ""
Write-Output "written: $reportPath"
