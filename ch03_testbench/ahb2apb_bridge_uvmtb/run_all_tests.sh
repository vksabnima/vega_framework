#!/bin/bash
VSIM="/c/intelFPGA/22.1std/questa_fse/win64/vsim"
TESTS=(
ahb2apb_bridge_bringup_test
ahb2apb_bridge_sanity_test
ahb2apb_bridge_datapath_001_test
ahb2apb_bridge_datapath_002_test
ahb2apb_bridge_datapath_003_test
ahb2apb_bridge_datapath_004_test
ahb2apb_bridge_datapath_005_test
ahb2apb_bridge_datapath_006_test
ahb2apb_bridge_datapath_007_test
ahb2apb_bridge_connectivity_001_test
ahb2apb_bridge_connectivity_002_test
ahb2apb_bridge_connectivity_003_test
ahb2apb_bridge_connectivity_004_test
ahb2apb_bridge_protocol_001_test
ahb2apb_bridge_protocol_002_test
ahb2apb_bridge_reg_access_001_test
ahb2apb_bridge_reg_access_002_test
ahb2apb_bridge_reg_access_003_test
ahb2apb_bridge_reg_access_004_test
ahb2apb_bridge_reg_access_005_test
ahb2apb_bridge_reg_access_006_test
ahb2apb_bridge_error_001_test
ahb2apb_bridge_error_002_test
ahb2apb_bridge_error_003_test
ahb2apb_bridge_error_004_test
ahb2apb_bridge_error_005_test
ahb2apb_bridge_error_006_test
ahb2apb_bridge_error_007_test
ahb2apb_bridge_reset_001_test
ahb2apb_bridge_reset_002_test
ahb2apb_bridge_reset_003_test
ahb2apb_bridge_reset_004_test
ahb2apb_bridge_reset_005_test
ahb2apb_bridge_stress_001_test
ahb2apb_bridge_cross_feature_001_test
ahb2apb_bridge_cross_feature_002_test
ahb2apb_bridge_cross_feature_003_test
ahb2apb_bridge_cross_feature_004_test
ahb2apb_bridge_protocol_003_test
ahb2apb_bridge_protocol_004_test
ahb2apb_bridge_datapath_008_test
ahb2apb_bridge_datapath_009_test
ahb2apb_bridge_datapath_010_test
ahb2apb_bridge_datapath_011_test
ahb2apb_bridge_error_008_test
ahb2apb_bridge_error_009_test
ahb2apb_bridge_error_010_test
ahb2apb_bridge_error_011_test
ahb2apb_bridge_error_012_test
)

PASS=0
FAIL=0
FAIL_LIST=""

# Collect all covered bins across regression
ALL_COVERED_BINS=""

for T in "${TESTS[@]}"; do
  LOG="logs/${T}.log"
  mkdir -p logs
  $VSIM -c -do "run -all; quit -f" tb_top_opt +UVM_TESTNAME=$T +UVM_VERBOSITY=UVM_LOW -suppress 8887 > "$LOG" 2>&1
  if grep -q "TEST PASSED" "$LOG"; then
    echo "PASS: $T"
    ((PASS++))
  else
    echo "FAIL: $T"
    ((FAIL++))
    FAIL_LIST="$FAIL_LIST $T"
  fi
  # Extract per-test overall coverage
  COV=$(grep "OVERALL" "$LOG" | grep -oP '\d+\.\d+%' | head -1)
  if [ -n "$COV" ]; then
    echo "      Coverage: $COV"
  fi
done

echo ""
echo "========================================="
echo "TOTAL: ${#TESTS[@]}  PASS: $PASS  FAIL: $FAIL"
if [ $FAIL -gt 0 ]; then
  echo "FAILED TESTS:$FAIL_LIST"
fi
echo "========================================="

# Print per-group coverage from last test (representative since it's single-test)
echo ""
echo "========= PER-TEST COVERAGE (last test) ========="
grep "COV" "logs/${TESTS[-1]}.log" | grep -v "UVM_INFO" | head -20
echo ""

# Collect unique covered bins across all test logs
echo "========= REGRESSION BIN ANALYSIS ========="
echo "Collecting covered bins across all 49 tests..."

# Count unique covered bins from all logs
TOTAL_EXPECTED=145
COVERED_FILE="logs/regression_covered_bins.txt"
> "$COVERED_FILE"
for T in "${TESTS[@]}"; do
  LOG="logs/${T}.log"
  # Extract uncovered bins list from each test
  # The covered bins = total - uncovered for that test
done

# Extract the UNCOVERED BINS from each test log, then find bins that are
# uncovered in ALL tests (never covered in any test)
UNCOV_FILE="logs/regression_uncovered.txt"
> "$UNCOV_FILE"

# Get the full uncovered list from any test that has it
for T in "${TESTS[@]}"; do
  LOG="logs/${T}.log"
  grep -oP '(?<=    )\S+\.\S+' "$LOG" >> "$UNCOV_FILE" 2>/dev/null
done

# Sort unique — bins appearing in ALL 49 logs are never covered
if [ -s "$UNCOV_FILE" ]; then
  sort "$UNCOV_FILE" | uniq -c | sort -rn > "logs/regression_bin_frequency.txt"
  # Bins uncovered in ALL tests (count == number of tests)
  NEVER_COVERED=$(awk -v n=${#TESTS[@]} '$1 == n {print $2}' "logs/regression_bin_frequency.txt" | wc -l)
  REGRESSION_HITS=$((TOTAL_EXPECTED - NEVER_COVERED))
  REGRESSION_COV=$(echo "scale=1; $REGRESSION_HITS * 100 / $TOTAL_EXPECTED" | bc)
  echo "Total bins:     $TOTAL_EXPECTED"
  echo "Covered bins:   $REGRESSION_HITS"
  echo "Uncovered bins: $NEVER_COVERED"
  echo "REGRESSION COVERAGE: ${REGRESSION_COV}%"
  echo ""
  if [ $NEVER_COVERED -gt 0 ]; then
    echo "Never-covered bins:"
    awk -v n=${#TESTS[@]} '$1 == n {print "  " $2}' "logs/regression_bin_frequency.txt"
  fi
fi
echo "========================================="
