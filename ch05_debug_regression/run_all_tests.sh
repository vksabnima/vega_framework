#!/bin/bash
# =============================================================================
# run_all_tests.sh — Full regression runner (ch05_debug_regression)
#
# Runs from ch05_debug_regression/, compiles in ch03's TB directory,
# runs all 49 tests, collects coverage.
# Logs and results are saved in ch05_debug_regression/logs/.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TB_DIR="$SCRIPT_DIR/../ch03_testbench/ahb2apb_bridge_uvmtb"
VSIM="/c/intelFPGA/22.1std/questa_fse/win64/vsim"
VLIB="/c/intelFPGA/22.1std/questa_fse/win64/vlib"
VLOG="/c/intelFPGA/22.1std/questa_fse/win64/vlog"
VOPT="/c/intelFPGA/22.1std/questa_fse/win64/vopt"
UVM_HOME="/c/intelFPGA/22.1std/questa_fse/verilog_src/uvm-1.1d"

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"

# --- Step 1: Compile from ch03 TB directory ---
echo "========================================="
echo "COMPILING from $TB_DIR"
echo "========================================="
cd "$TB_DIR"
rm -rf work
$VLIB work
$VLOG -sv -timescale 1ns/1ps \
    +define+UVM_NO_DPI \
    "+incdir+$UVM_HOME/src" \
    "+incdir+." \
    -f tb_list.f \
    "$UVM_HOME/src/uvm_pkg.sv"

if [ $? -ne 0 ]; then
    echo "*** COMPILE FAILED ***"
    exit 1
fi

$VOPT tb_top -o tb_top_opt +acc
if [ $? -ne 0 ]; then
    echo "*** ELABORATE FAILED ***"
    exit 1
fi
echo "*** COMPILE + ELABORATE PASSED ***"
echo ""

# --- Step 2: Run all tests ---
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
ahb2apb_bridge_datapath_008_test
ahb2apb_bridge_datapath_009_test
ahb2apb_bridge_datapath_010_test
ahb2apb_bridge_datapath_011_test
ahb2apb_bridge_connectivity_001_test
ahb2apb_bridge_connectivity_002_test
ahb2apb_bridge_connectivity_003_test
ahb2apb_bridge_connectivity_004_test
ahb2apb_bridge_protocol_001_test
ahb2apb_bridge_protocol_002_test
ahb2apb_bridge_protocol_003_test
ahb2apb_bridge_protocol_004_test
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
ahb2apb_bridge_error_008_test
ahb2apb_bridge_error_009_test
ahb2apb_bridge_error_010_test
ahb2apb_bridge_error_011_test
ahb2apb_bridge_error_012_test
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
)

PASS=0
FAIL=0
FAIL_LIST=""

for T in "${TESTS[@]}"; do
  LOG="$LOG_DIR/${T}.log"
  $VSIM -c -do "run -all; quit -f" tb_top_opt +UVM_TESTNAME=$T +UVM_VERBOSITY=UVM_LOW -suppress 8887 > "$LOG" 2>&1
  if grep -q "TEST PASSED" "$LOG"; then
    echo "PASS: $T"
    ((PASS++))
  else
    echo "FAIL: $T"
    ((FAIL++))
    FAIL_LIST="$FAIL_LIST $T"
  fi
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

# --- Step 3: Coverage analysis ---
echo ""
echo "========= PER-TEST COVERAGE (last test) ========="
grep "COV" "$LOG_DIR/${TESTS[-1]}.log" | grep -v "UVM_INFO" | head -20
echo ""

echo "========= REGRESSION BIN ANALYSIS ========="
echo "Collecting covered bins across all ${#TESTS[@]} tests..."

TOTAL_EXPECTED=145
UNCOV_FILE="$LOG_DIR/regression_uncovered.txt"
> "$UNCOV_FILE"

for T in "${TESTS[@]}"; do
  LOG="$LOG_DIR/${T}.log"
  grep -oP '(?<=    )\S+\.\S+' "$LOG" >> "$UNCOV_FILE" 2>/dev/null
done

if [ -s "$UNCOV_FILE" ]; then
  sort "$UNCOV_FILE" | uniq -c | sort -rn > "$LOG_DIR/regression_bin_frequency.txt"
  NEVER_COVERED=$(awk -v n=${#TESTS[@]} '$1 == n {print $2}' "$LOG_DIR/regression_bin_frequency.txt" | wc -l)
  REGRESSION_HITS=$((TOTAL_EXPECTED - NEVER_COVERED))
  REGRESSION_COV=$(echo "scale=1; $REGRESSION_HITS * 100 / $TOTAL_EXPECTED" | bc)
  echo "Total bins:     $TOTAL_EXPECTED"
  echo "Covered bins:   $REGRESSION_HITS"
  echo "Uncovered bins: $NEVER_COVERED"
  echo "REGRESSION COVERAGE: ${REGRESSION_COV}%"
  echo ""
  if [ $NEVER_COVERED -gt 0 ]; then
    echo "Never-covered bins:"
    awk -v n=${#TESTS[@]} '$1 == n {print "  " $2}' "$LOG_DIR/regression_bin_frequency.txt"
  fi
fi
echo "========================================="
