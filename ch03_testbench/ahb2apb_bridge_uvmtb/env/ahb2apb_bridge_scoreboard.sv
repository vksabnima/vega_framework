// =============================================================================
// File        : ahb2apb_bridge_scoreboard.sv
// Description : Scoreboard implementing all verification goals
//
// Receives AHB transactions from ahb_mst_monitor and APB transactions from
// apb_slv_monitor via analysis ports.  Compares them to verify:
//
//   VG1: Address passthrough — HADDR == PADDR
//   VG2: Write data integrity — HWDATA == PWDATA (for writes)
//   VG3: Read data integrity  — PRDATA == HRDATA (for reads)
//   VG4: Direction preservation — HWRITE == PWRITE
//   VG5: Error propagation — PSLVERR → HRESP (not injected in bringup,
//        but verify no-error case: both should be 0)
//   VG6: No lost/duplicated — AHB count == APB count, queues empty at end
//
// Architecture:
//   Two FIFOs (queues) — one for AHB, one for APB.
//   Comparison happens whenever both queues have at least one entry.
//   In-order comparison assumes bridge preserves transaction order (no
//   reordering for single transfers).
//
// Derivation:
//   - Intent: all CHECK items
//   - Manifest: verification_goals VG1–VG6
//
// Confidence: HIGH — straightforward FIFO-based scoreboard.
// =============================================================================

// Per [U5]: analysis_imp_decl macros MUST be at file scope before class
`uvm_analysis_imp_decl(_ahb)
`uvm_analysis_imp_decl(_apb)

class ahb2apb_bridge_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(ahb2apb_bridge_scoreboard)

  // Analysis implementation ports — one per interface
  uvm_analysis_imp_ahb #(ahb_mst_seq_item, ahb2apb_bridge_scoreboard) ahb_imp;
  uvm_analysis_imp_apb #(apb_slv_seq_item, ahb2apb_bridge_scoreboard) apb_imp;

  // Transaction queues for in-order comparison
  ahb_mst_seq_item ahb_q[$];
  apb_slv_seq_item apb_q[$];

  // Counters for VG6
  int ahb_txn_count;
  int apb_txn_count;

  // Pass/fail tracking per VG
  int vg_pass[string];
  int vg_fail[string];

  // Enable flag — disabled for bringup test
  bit enable = 1;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ahb_txn_count = 0;
    apb_txn_count = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ahb_imp = new("ahb_imp", this);
    apb_imp = new("apb_imp", this);

    // Initialize VG counters
    vg_pass["VG1"] = 0; vg_fail["VG1"] = 0;
    vg_pass["VG2"] = 0; vg_fail["VG2"] = 0;
    vg_pass["VG3"] = 0; vg_fail["VG3"] = 0;
    vg_pass["VG4"] = 0; vg_fail["VG4"] = 0;
    vg_pass["VG5"] = 0; vg_fail["VG5"] = 0;
    vg_pass["VG6"] = 0; vg_fail["VG6"] = 0;
  endfunction

  // =========================================================================
  // write_ahb — called by ahb_mst_monitor's analysis port
  //
  // Pushes AHB transaction into queue, then attempts comparison.
  // =========================================================================
  virtual function void write_ahb(ahb_mst_seq_item txn);
    if (!enable) return;
    ahb_q.push_back(txn);
    ahb_txn_count++;
    `uvm_info("SCB", $sformatf("AHB txn #%0d received: %s", ahb_txn_count, txn.convert2string()), UVM_MEDIUM)
    try_compare();
  endfunction

  // =========================================================================
  // write_apb — called by apb_slv_monitor's analysis port
  //
  // Pushes APB transaction into queue, then attempts comparison.
  // =========================================================================
  virtual function void write_apb(apb_slv_seq_item txn);
    if (!enable) return;
    apb_q.push_back(txn);
    apb_txn_count++;
    `uvm_info("SCB", $sformatf("APB txn #%0d received: %s", apb_txn_count, txn.convert2string()), UVM_MEDIUM)
    try_compare();
  endfunction

  // =========================================================================
  // try_compare — compare AHB and APB transactions in order
  //
  // Called after each new transaction arrives.  If both queues have entries,
  // pop one from each and run all VG checks.
  //
  // Assumption: transactions arrive in order (FIFO, no reordering).
  // =========================================================================
  virtual function void try_compare();
    ahb_mst_seq_item ahb_txn;
    apb_slv_seq_item apb_txn;

    while (ahb_q.size() > 0 && apb_q.size() > 0) begin
      ahb_txn = ahb_q.pop_front();
      apb_txn = apb_q.pop_front();

      // ----- VG1: Address passthrough -----
      // "Every transaction address driven on the AHB interface must appear
      //  unchanged on the APB interface"
      if (ahb_txn.HADDR === apb_txn.PADDR) begin
        vg_pass["VG1"]++;
        `uvm_info("SCB_VG1", $sformatf("PASS: HADDR=0x%08h == PADDR=0x%08h",
                  ahb_txn.HADDR, apb_txn.PADDR), UVM_MEDIUM)
      end else begin
        vg_fail["VG1"]++;
        `uvm_error("SCB_VG1", $sformatf("FAIL: HADDR=0x%08h != PADDR=0x%08h",
                   ahb_txn.HADDR, apb_txn.PADDR))
      end

      // ----- VG4: Direction preservation -----
      // "A write on AHB must produce a write on APB. Direction cannot flip."
      if (ahb_txn.HWRITE === apb_txn.PWRITE) begin
        vg_pass["VG4"]++;
        `uvm_info("SCB_VG4", $sformatf("PASS: HWRITE=%0b == PWRITE=%0b",
                  ahb_txn.HWRITE, apb_txn.PWRITE), UVM_MEDIUM)
      end else begin
        vg_fail["VG4"]++;
        `uvm_error("SCB_VG4", $sformatf("FAIL: HWRITE=%0b != PWRITE=%0b",
                   ahb_txn.HWRITE, apb_txn.PWRITE))
      end

      // ----- VG2: Write data integrity -----
      // "Write data sent on AHB must reach APB without corruption"
      // Only checked for write transactions
      if (ahb_txn.HWRITE == 1'b1) begin
        if (ahb_txn.HWDATA === apb_txn.PWDATA) begin
          vg_pass["VG2"]++;
          `uvm_info("SCB_VG2", $sformatf("PASS: HWDATA=0x%08h == PWDATA=0x%08h",
                    ahb_txn.HWDATA, apb_txn.PWDATA), UVM_MEDIUM)
        end else begin
          vg_fail["VG2"]++;
          `uvm_error("SCB_VG2", $sformatf("FAIL: HWDATA=0x%08h != PWDATA=0x%08h",
                     ahb_txn.HWDATA, apb_txn.PWDATA))
        end
      end

      // ----- VG3: Read data integrity -----
      // "Read data returned from APB must reach the AHB master unchanged"
      // Only checked for read transactions
      if (ahb_txn.HWRITE == 1'b0) begin
        if (apb_txn.PRDATA === ahb_txn.HRDATA) begin
          vg_pass["VG3"]++;
          `uvm_info("SCB_VG3", $sformatf("PASS: PRDATA=0x%08h == HRDATA=0x%08h",
                    apb_txn.PRDATA, ahb_txn.HRDATA), UVM_MEDIUM)
        end else begin
          vg_fail["VG3"]++;
          `uvm_error("SCB_VG3", $sformatf("FAIL: PRDATA=0x%08h != HRDATA=0x%08h",
                     apb_txn.PRDATA, ahb_txn.HRDATA))
        end
      end

      // ----- VG5: Error propagation -----
      // "An error response from APB slave must be visible on AHB side"
      // For bringup: no errors injected — verify both sides show no error
      if (apb_txn.PSLVERR === ahb_txn.HRESP) begin
        vg_pass["VG5"]++;
        `uvm_info("SCB_VG5", $sformatf("PASS: PSLVERR=%0b == HRESP=%0b",
                  apb_txn.PSLVERR, ahb_txn.HRESP), UVM_MEDIUM)
      end else begin
        vg_fail["VG5"]++;
        `uvm_error("SCB_VG5", $sformatf("FAIL: PSLVERR=%0b != HRESP=%0b",
                   apb_txn.PSLVERR, ahb_txn.HRESP))
      end
    end
  endfunction

  // =========================================================================
  // check_phase: final verification at end of simulation
  //
  // VG6: No lost or duplicated transactions
  //   - AHB count must equal APB count
  //   - Both queues must be empty (no unmatched transactions)
  // Also report summary for all VGs.
  // =========================================================================
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    if (!enable) begin
      `uvm_info("SCB", "Scoreboard disabled — skipping check_phase", UVM_LOW)
      return;
    end

    `uvm_info("SCB", "========== SCOREBOARD CHECK PHASE ==========", UVM_LOW)

    // ----- VG6: Transaction count -----
    if (ahb_txn_count == apb_txn_count && ahb_q.size() == 0 && apb_q.size() == 0) begin
      vg_pass["VG6"] = 1;
      `uvm_info("SCB_VG6", $sformatf("PASS: AHB=%0d APB=%0d transactions, queues empty",
                ahb_txn_count, apb_txn_count), UVM_LOW)
    end else begin
      vg_fail["VG6"] = 1;
      `uvm_error("SCB_VG6", $sformatf("FAIL: AHB=%0d APB=%0d transactions, ahb_q=%0d apb_q=%0d remaining",
                 ahb_txn_count, apb_txn_count, ahb_q.size(), apb_q.size()))
    end

    // ----- Summary Report -----
    `uvm_info("SCB", "---------- Verification Goal Summary ----------", UVM_LOW)
    `uvm_info("SCB", $sformatf("VG1 (Address)   : PASS=%0d FAIL=%0d", vg_pass["VG1"], vg_fail["VG1"]), UVM_LOW)
    `uvm_info("SCB", $sformatf("VG2 (Write Data) : PASS=%0d FAIL=%0d", vg_pass["VG2"], vg_fail["VG2"]), UVM_LOW)
    `uvm_info("SCB", $sformatf("VG3 (Read Data)  : PASS=%0d FAIL=%0d", vg_pass["VG3"], vg_fail["VG3"]), UVM_LOW)
    `uvm_info("SCB", $sformatf("VG4 (Direction)  : PASS=%0d FAIL=%0d", vg_pass["VG4"], vg_fail["VG4"]), UVM_LOW)
    `uvm_info("SCB", $sformatf("VG5 (Error Prop) : PASS=%0d FAIL=%0d", vg_pass["VG5"], vg_fail["VG5"]), UVM_LOW)
    `uvm_info("SCB", $sformatf("VG6 (Count Match): PASS=%0d FAIL=%0d", vg_pass["VG6"], vg_fail["VG6"]), UVM_LOW)
    `uvm_info("SCB", "------------------------------------------------", UVM_LOW)
  endfunction

  // =========================================================================
  // report_phase: print transaction summary and final PASS/FAIL
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    int total_fail;
    int matched;
    super.report_phase(phase);

    if (!enable) return;

    matched = vg_pass["VG1"] + vg_fail["VG1"];  // each compared pair counts once

    `uvm_info("SCB", "---------- Transaction Summary ----------", UVM_LOW)
    `uvm_info("SCB", $sformatf("  AHB sent     : %0d", ahb_txn_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  APB received : %0d", apb_txn_count), UVM_LOW)
    `uvm_info("SCB", $sformatf("  Matched      : %0d", matched), UVM_LOW)

    // Print unmatched AHB transactions still waiting for APB side
    if (ahb_q.size() > 0) begin
      `uvm_warning("SCB", $sformatf("  %0d AHB transaction(s) never appeared on APB (stuck in expected queue):",
                   ahb_q.size()))
      foreach (ahb_q[i])
        `uvm_warning("SCB", $sformatf("    [%0d] %s", i, ahb_q[i].convert2string()))
    end

    // Print unmatched APB transactions with no corresponding AHB entry
    if (apb_q.size() > 0) begin
      `uvm_warning("SCB", $sformatf("  %0d APB transaction(s) with no matching AHB entry:",
                   apb_q.size()))
      foreach (apb_q[i])
        `uvm_warning("SCB", $sformatf("    [%0d] %s", i, apb_q[i].convert2string()))
    end

    `uvm_info("SCB", "----------------------------------------", UVM_LOW)

    total_fail = vg_fail["VG1"] + vg_fail["VG2"] + vg_fail["VG3"] +
                 vg_fail["VG4"] + vg_fail["VG5"] + vg_fail["VG6"];

    if (total_fail == 0)
      `uvm_info("SCB", "========== ALL VERIFICATION GOALS PASSED ==========", UVM_NONE)
    else
      `uvm_error("SCB", $sformatf("========== %0d VERIFICATION GOAL FAILURES ==========", total_fail))
  endfunction

endclass