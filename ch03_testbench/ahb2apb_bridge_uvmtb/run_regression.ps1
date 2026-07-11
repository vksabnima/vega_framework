# run_regression.ps1 — run every UVM test, score PASS/FAIL from the UVM report summary.
$ErrorActionPreference = "Stop"
$root = "C:\Users\ritup\Desktop\vikash_projects\vega_framework\ch03_testbench\ahb2apb_bridge_uvmtb"
Set-Location $root
$q = "C:\intelFPGA\22.1std\questa_fse"
$logdir = Join-Path $root "regression_logs"
New-Item -ItemType Directory -Force -Path $logdir | Out-Null

# Collect every UVM test class name from tests/*.sv
$tests = Get-ChildItem (Join-Path $root "tests") -Filter *.sv |
    ForEach-Object {
        Select-String -Path $_.FullName -Pattern 'uvm_component_utils\(\s*([A-Za-z0-9_]+)' |
        ForEach-Object { $_.Matches[0].Groups[1].Value }
    } | Sort-Object -Unique

$summary = @()
$i = 0
foreach ($t in $tests) {
    $i++
    $log = Join-Path $logdir "$t.log"
    Write-Host "[$i/$($tests.Count)] $t ..." -NoNewline
    & "$q\win64\vsim" -c tb_top_opt +UVM_TESTNAME=$t +UVM_NO_RELNOTES -do "run -all; quit -f" *> $log

    $txt = Get-Content $log -Raw
    $err = if ($txt -match 'UVM_ERROR\s*[:=]\s*(\d+)')  { [int]$Matches[1] } else { -1 }
    $fat = if ($txt -match 'UVM_FATAL\s*[:=]\s*(\d+)')  { [int]$Matches[1] } else { -1 }
    $hasSummary = $txt -match 'UVM Report Summary'
    $testFailed = $txt -match 'TEST FAILED'

    if ($hasSummary -and $err -eq 0 -and $fat -eq 0 -and -not $testFailed) {
        $status = "PASS"
    } elseif (-not $hasSummary) {
        $status = "NO_FINISH"
    } else {
        $status = "FAIL"
    }
    Write-Host " $status (ERR=$err FATAL=$fat)"
    $summary += [pscustomobject]@{ Test = $t; Status = $status; Errors = $err; Fatals = $fat }
}

Write-Host "`n================ REGRESSION SUMMARY ================"
$summary | Group-Object Status | ForEach-Object { Write-Host ("{0,-10} : {1}" -f $_.Name, $_.Count) }
Write-Host "---------------------------------------------------"
$summary | Where-Object { $_.Status -ne "PASS" } | ForEach-Object {
    Write-Host ("FAILING: {0,-32} {1} (ERR={2} FATAL={3})" -f $_.Test, $_.Status, $_.Errors, $_.Fatals)
}
$summary | Export-Csv -NoTypeInformation -Path (Join-Path $root "regression_summary.csv")
Write-Host "`nTotal: $($summary.Count)  |  CSV: regression_summary.csv"
