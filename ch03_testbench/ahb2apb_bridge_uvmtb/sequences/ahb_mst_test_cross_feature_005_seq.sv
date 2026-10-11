// =============================================================================
// FILE: sequences/ahb_mst_test_cross_feature_005_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CROSS_FEATURE_005
// DESCRIPTION: Stimulus for hsel_deassert_mid_transfer. Exposes protocol/
//              state-machine faults when HSEL is deasserted (HSEL=0) after a
//              transfer has been captured but before target completion.
//              Connectivity and protocol features alone do not cover the
//              deselect-during-active-phase interaction — the bug only appears
//              when an already-captured beat is still in flight in the target
//              (PREADY held low) and the source select is dropped.
//
//              All stimulus is issued as raw AHB transactions. The data-plane
//              read targets the legal region 0x0000_0000-0x0000_FFFF; the back-
//              pressure (PREADY=0 for two cycles then PRDATA=0xBEEF_CACE) and
//              the HSEL-deassert idle beat are produced by the AHB master driver
//              / APB slave harness. The scoreboard validates that the captured
//              read completes (HRDATA=0xBEEF_CACE, HRESP=0), that no spurious
//              second APB transfer is launched from the deselected cycle (VG6),
//              and that the FSM returns to a clean IDLE (STATUS=0x00000001).
//
// REGISTER MAP (raw AHB accesses to the register block):
//   STATUS     = 0xF04  (READY b0, BUSY b1, sticky error bits, ...)
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_005 steps T1-T7 — drive a read transfer to
//     0x0000_6000 that the peripheral stalls (PREADY=0, two cycles) then
//     completes with PRDATA=0xBEEF_CACE; deassert HSEL (HTRANS=IDLE) mid-
//     transfer; confirm the in-flight beat completes (HRDATA=0xBEEF_CACE,
//     HRESP=0), no second transfer is launched, then read STATUS to confirm a
//     clean IDLE (STATUS=0x0000_0001).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — the
//       STATUS access is a raw AHB transaction to 0xF04.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_cross_feature_005_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_cross_feature_005_seq)

  // ── Register block offset (raw AHB access to the control/status block) ──────
  localparam logic [31:0] REG_STATUS = 32'h0000_0F04;

  // ── Data-plane address / expected payload for the stalled read transfer ─────
  localparam logic [31:0] ADDR_RD    = 32'h0000_6000;  // read addr captured at T1
  localparam logic [31:0] DATA_RD    = 32'hBEEF_CACE;  // PRDATA returned at T5

  function new(string name = "ahb_mst_test_cross_feature_005_seq");
    super.new(name);
  endfunction : new

  // ── Helper: drive a single word READ transaction ──────────────────────────
  task automatic do_read(input logic [31:0] addr, input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_rd_%s", tag));
    start_item(req);
    req.addr       = addr;
    req.write      = 1'b0;
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("XFEAT005_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("XFEAT005_SEQ",
      "Starting TEST_CROSS_FEATURE_005: HSEL deassert mid-transfer",
      UVM_MEDIUM)

    // ── T1-T5: stalled read transfer captured at the source ─────────────────
    // At T1 the source captures the read to 0x0000_6000 (FSM IDLE->SETUP,
    // BUSY=1). The target setup (PSEL=1) and active phase (PENABLE=1) follow
    // with PREADY held low for two cycles (back-pressure, HREADY_OUT=0). At T4
    // the source select is deasserted mid-transfer (HSEL=0, HTRANS=IDLE) while
    // the captured beat is still active in the target — this must NOT abort or
    // corrupt the in-flight operation. At T5 the peripheral completes with
    // PRDATA=0xBEEF_CACE / PSLVERR=0, and the read data is returned for the
    // original transfer only (HRDATA=0xBEEF_CACE, HRESP=0). The stall, the
    // HSEL-deassert idle beat and the completion are produced by the driver /
    // APB slave harness.
    do_read(ADDR_RD, "stalled_read");

    // ── T6-T7: confirm clean IDLE — no spurious second transfer was launched ─
    // from the HSEL=0/HTRANS=IDLE cycle (PSEL stays 0), and STATUS reads back
    // 0x0000_0001 (BUSY=0, READY=1, no sticky error from the mid-transfer
    // deselect).
    do_read(REG_STATUS, "status_after");

    `uvm_info("XFEAT005_SEQ", "TEST_CROSS_FEATURE_005 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_cross_feature_005_seq
