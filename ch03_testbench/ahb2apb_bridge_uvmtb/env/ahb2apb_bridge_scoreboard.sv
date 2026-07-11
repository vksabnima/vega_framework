// =============================================================================
// FILE: env/ahb2apb_bridge_scoreboard.sv
// =============================================================================
// COMPONENT  : AHB-to-APB Bridge Scoreboard
// DESCRIPTION: Receives AHB and APB transactions from monitors and verifies
//              all six verification goals (VG1-VG6).
//
// DERIVED FROM:
//   - Intent (CHECK section):
//     VG1: Address must be identical on both sides
//     VG2: Write data must not be corrupted
//     VG3: Read data must return intact
//     VG4: Transfer direction must be preserved
//     VG5: Error responses must propagate
//     VG6: No transactions lost or duplicated
//   - Manifest: verification_goals list with priorities.
//
// ARCHITECTURE:
//   - Two analysis ports: ahb_ap (from AHB monitor) and apb_ap (from APB monitor)
//   - AHB transactions queued in ahb_q
//   - APB transactions queued in apb_q
//   - When both queues have items, compare head-to-head (in-order)
//   - End-of-test check: both queues must be empty (VG6)
//
// CONFIDENCE: HIGH — straightforward queue-based comparison.
// =============================================================================

// Analysis imp declarations at file scope before class definition [U5]
`uvm_analysis_imp_decl(_ahb)
`uvm_analysis_imp_decl(_apb)

class ahb2apb_bridge_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(ahb2apb_bridge_scoreboard)

  // ── Analysis Imports ─────────────────────────────────────────────────────
  // Two analysis imports: one for AHB transactions, one for APB transactions.
  // Declared using macros above [U5].
  uvm_analysis_imp_ahb #(ahb_mst_seq_item, ahb2apb_bridge_scoreboard) ahb_ap;
  uvm_analysis_imp_apb #(apb_slv_seq_item, ahb2apb_bridge_scoreboard) apb_ap;

  // ── Transaction Queues ───────────────────────────────────────────────────
  // AHB transactions arrive from AHB monitor, APB from APB monitor.
  // Since bridge translates 1:1, we compare in-order.
  ahb_mst_seq_item ahb_q[$];
  apb_slv_seq_item apb_q[$];

  // ── Counters ─────────────────────────────────────────────────────────────
  int unsigned ahb_txn_count = 0;
  int unsigned apb_txn_count = 0;
  int unsigned match_count   = 0;
  int unsigned error_count   = 0;

  // ── Bridge address map (must match rtl_Design/ahb2apb_bridge.sv) ───────────
  // Only transactions the bridge FORWARDS to APB participate in the AHB<->APB
  // pairing checks (VG1-VG6). The bridge does NOT forward:
  //   - internal register-block accesses (REG_BASE .. REG_BASE+0xF): these are
  //     serviced by ST_REG_READ and never produce APB traffic
  //   - address-decode errors (addr outside the APB data range): these return
  //     a 2-cycle HRESP error with no APB transaction
  // Pairing those against APB transactions would desync the in-order queues and
  // produce spurious VG1/VG2/VG3/VG6 mismatches. Such transactions are checked
  // by the individual tests instead (via req.rdata/req.resp self-checks).
  localparam logic [31:0] APB_ADDR_START = 32'h0000_0000;
  localparam logic [31:0] APB_ADDR_END   = 32'h0000_FFFF;
  localparam logic [31:0] REG_BASE       = 32'h0000_0F00;
  localparam logic [31:0] REG_END        = REG_BASE + 32'h10;  // exclusive

  // True when an AHB transaction is forwarded to the APB side by the bridge.
  function bit is_forwarded_to_apb(ahb_mst_seq_item txn);
    bit in_apb_range = (txn.addr >= APB_ADDR_START) && (txn.addr <= APB_ADDR_END);
    bit in_reg_range = (txn.addr >= REG_BASE)       && (txn.addr <  REG_END);
    return in_apb_range && !in_reg_range;
  endfunction : is_forwarded_to_apb

  function new(string name = "ahb2apb_bridge_scoreboard", uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ahb_ap = new("ahb_ap", this);
    apb_ap = new("apb_ap", this);
  endfunction : build_phase

  // ── Write Callbacks ──────────────────────────────────────────────────────
  // Called by analysis ports when monitors broadcast transactions.

  // AHB monitor callback — queue AHB transaction and attempt compare.
  // Only transactions the bridge forwards to APB take part in VG1-VG6; register
  // accesses and decode-errors are checked by the tests themselves.
  function void write_ahb(ahb_mst_seq_item txn);
    if (!is_forwarded_to_apb(txn)) begin
      `uvm_info("SCB",
        $sformatf("AHB TXN to 0x%08h not forwarded to APB (register/decode-error) — excluded from AHB<->APB pairing",
                  txn.addr), UVM_HIGH)
      return;
    end
    ahb_q.push_back(txn);
    ahb_txn_count++;
    `uvm_info("SCB", $sformatf("AHB TXN #%0d received: %s", ahb_txn_count, txn.convert2string()), UVM_HIGH)
    compare_txns();
  endfunction : write_ahb

  // APB monitor callback — queue APB transaction and attempt compare
  function void write_apb(apb_slv_seq_item txn);
    apb_q.push_back(txn);
    apb_txn_count++;
    `uvm_info("SCB", $sformatf("APB TXN #%0d received: %s", apb_txn_count, txn.convert2string()), UVM_HIGH)
    compare_txns();
  endfunction : write_apb

  // ── Compare Logic ────────────────────────────────────────────────────────
  // When both queues have at least one item, pop and compare.
  function void compare_txns();
    ahb_mst_seq_item ahb_txn;
    apb_slv_seq_item apb_txn;

    while (ahb_q.size() > 0 && apb_q.size() > 0) begin
      ahb_txn = ahb_q.pop_front();
      apb_txn = apb_q.pop_front();

      `uvm_info("SCB", $sformatf("Comparing AHB vs APB transaction #%0d", match_count+1), UVM_MEDIUM)

      // ── VG1: Address must be identical ─────────────────────────────────
      // Intent: "Every transaction address driven on AHB must appear
      //          unchanged on APB"
      if (ahb_txn.addr !== apb_txn.addr) begin
        `uvm_error("SCB_VG1",
          $sformatf("VG1 FAIL — Address mismatch: AHB=0x%08h APB=0x%08h",
                    ahb_txn.addr, apb_txn.addr))
        error_count++;
      end else begin
        `uvm_info("SCB_VG1",
          $sformatf("VG1 PASS — Address match: 0x%08h", ahb_txn.addr), UVM_HIGH)
      end

      // ── VG2: Write data must not be corrupted ──────────────────────────
      // Intent: "Write data sent on AHB must reach APB without corruption"
      // Only check for write transactions
      if (ahb_txn.write === 1'b1) begin
        if (ahb_txn.wdata !== apb_txn.wdata) begin
          `uvm_error("SCB_VG2",
            $sformatf("VG2 FAIL — Write data mismatch: AHB=0x%08h APB=0x%08h",
                      ahb_txn.wdata, apb_txn.wdata))
          error_count++;
        end else begin
          `uvm_info("SCB_VG2",
            $sformatf("VG2 PASS — Write data match: 0x%08h", ahb_txn.wdata), UVM_HIGH)
        end
      end

      // ── VG3: Read data must return intact ──────────────────────────────
      // Intent: "Read data returned from APB must reach the AHB master
      //          unchanged"
      // Only check for read transactions
      if (ahb_txn.write === 1'b0) begin
        if (ahb_txn.rdata !== apb_txn.rdata) begin
          `uvm_error("SCB_VG3",
            $sformatf("VG3 FAIL — Read data mismatch: AHB=0x%08h APB=0x%08h",
                      ahb_txn.rdata, apb_txn.rdata))
          error_count++;
        end else begin
          `uvm_info("SCB_VG3",
            $sformatf("VG3 PASS — Read data match: 0x%08h", ahb_txn.rdata), UVM_HIGH)
        end
      end

      // ── VG4: Transfer direction must be preserved ──────────────────────
      // Intent: "A write on AHB must produce a write on APB.
      //          A read must produce a read."
      if (ahb_txn.write !== apb_txn.write) begin
        `uvm_error("SCB_VG4",
          $sformatf("VG4 FAIL — Direction mismatch: AHB=%s APB=%s",
                    ahb_txn.write ? "WR" : "RD",
                    apb_txn.write ? "WR" : "RD"))
        error_count++;
      end else begin
        `uvm_info("SCB_VG4",
          $sformatf("VG4 PASS — Direction match: %s",
                    ahb_txn.write ? "WR" : "RD"), UVM_HIGH)
      end

      // ── VG5: Error responses must propagate ────────────────────────────
      // Intent: "If APB slave signals error, must be visible on AHB side.
      //          For bringup — verify no-error case passes cleanly."
      // Check: if APB had PSLVERR=1, AHB should have HRESP=1 (and vice versa)
      if (apb_txn.slverr !== ahb_txn.resp) begin
        `uvm_error("SCB_VG5",
          $sformatf("VG5 FAIL — Error propagation mismatch: APB_SLVERR=%0b AHB_HRESP=%0b",
                    apb_txn.slverr, ahb_txn.resp))
        error_count++;
      end else begin
        `uvm_info("SCB_VG5",
          $sformatf("VG5 PASS — Error propagation match: PSLVERR=%0b HRESP=%0b",
                    apb_txn.slverr, ahb_txn.resp), UVM_HIGH)
      end

      match_count++;
    end
  endfunction : compare_txns

  // ── Check Phase: Final VG6 check ─────────────────────────────────────────
  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    // ── VG6: No transactions lost or duplicated ──────────────────────────
    // Intent: "The number of transactions observed on AHB must equal the
    //          number observed on APB. At end of simulation both monitor
    //          queues must be empty."
    if (ahb_q.size() != 0) begin
      `uvm_error("SCB_VG6",
        $sformatf("VG6 FAIL — %0d unmatched AHB transactions remaining in queue",
                  ahb_q.size()))
      error_count++;
    end

    if (apb_q.size() != 0) begin
      `uvm_error("SCB_VG6",
        $sformatf("VG6 FAIL — %0d unmatched APB transactions remaining in queue",
                  apb_q.size()))
      error_count++;
    end

    if (ahb_txn_count != apb_txn_count) begin
      `uvm_error("SCB_VG6",
        $sformatf("VG6 FAIL — Transaction count mismatch: AHB=%0d APB=%0d",
                  ahb_txn_count, apb_txn_count))
      error_count++;
    end else begin
      `uvm_info("SCB_VG6",
        $sformatf("VG6 PASS — Transaction count match: AHB=%0d APB=%0d",
                  ahb_txn_count, apb_txn_count), UVM_LOW)
    end

    // ── Summary Report ───────────────────────────────────────────────────
    `uvm_info("SCB",
      $sformatf("\n========== SCOREBOARD SUMMARY ==========\n  AHB transactions: %0d\n  APB transactions: %0d\n  Matched: %0d\n  Errors: %0d\n==========================================",
                ahb_txn_count, apb_txn_count, match_count, error_count), UVM_LOW)
  endfunction : check_phase

  // ── Report Phase: Final pass/fail ────────────────────────────────────────
  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    if (error_count == 0 && match_count > 0) begin
      `uvm_info("SCB", "*** ALL VERIFICATION GOALS PASSED ***", UVM_NONE)
    end else if (match_count == 0) begin
      `uvm_warning("SCB", "No transactions were compared — check stimulus")
    end else begin
      `uvm_error("SCB",
        $sformatf("*** VERIFICATION FAILED — %0d errors detected ***", error_count))
    end
  endfunction : report_phase

endclass : ahb2apb_bridge_scoreboard