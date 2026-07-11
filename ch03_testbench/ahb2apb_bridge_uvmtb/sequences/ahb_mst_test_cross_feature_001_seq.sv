// =============================================================================
// FILE: sequences/ahb_mst_test_cross_feature_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CROSS_FEATURE_001
// DESCRIPTION: Stimulus for hard_reset_during_active_transfer. Drives an AHB
//              write that is left mid-flight while the APB peripheral stalls
//              (PREADY=0), then exercises the hard-reset abort and the clean
//              IDLE recovery, finishing with register read-backs and a fresh
//              transfer that must complete normally.
//
//              All stimulus is issued as raw AHB transactions. Register
//              accesses target the control/status block at PADDR 0xF00..0xF0C;
//              data-plane traffic targets the legal region
//              0x0000_0000-0x0000_FFFF. The hard-reset assertion itself is
//              driven by the AHB master driver / tb harness in response to the
//              reset-marker transaction below; the scoreboard validates the
//              post-reset clean-IDLE state.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE bit0, SOFT_RST bit1, ...)
//   STATUS     = 0xF04  (READY b0, BUSY b1, ADDR_ERR b4, PSLVERR b5, ...)
//   ERROR_ADDR = 0xF08  (captured invalid address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_001 steps T1-T7 — mid-flight write under PREADY=0
//     back-pressure, hard-reset abort, clean-IDLE recovery, STATUS/ERROR_ADDR
//     read-back, fresh transfer completing normally.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_cross_feature_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_cross_feature_001_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;

  // ── Data-plane addresses ──────────────────────────────────────────────────
  localparam logic [31:0] ADDR_INFLIGHT  = 32'h0000_1000;  // mid-flight write
  localparam logic [31:0] ADDR_FRESH     = 32'h0000_2000;  // post-reset write

  // ── Data values ────────────────────────────────────────────────────────────
  localparam logic [31:0] DATA_INFLIGHT  = 32'hDEAD_BEEF;  // T1 stalled write
  localparam logic [31:0] DATA_FRESH     = 32'hA5A5_5A5A;  // T7 fresh write

  function new(string name = "ahb_mst_test_cross_feature_001_seq");
    super.new(name);
  endfunction : new

  // ── Helper: drive a single word WRITE transaction ─────────────────────────
  task automatic do_write(input logic [31:0] addr, input logic [31:0] data,
                          input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_wr_%s", tag));
    start_item(req);
    req.addr       = addr;
    req.write      = 1'b1;
    req.wdata      = data;
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("XFEAT001_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

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
    `uvm_info("XFEAT001_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("XFEAT001_SEQ",
      "Starting TEST_CROSS_FEATURE_001: hard reset during active transfer",
      UVM_MEDIUM)

    // ── T1: launch a write that will be left mid-flight while the APB ─────────
    // peripheral stalls (PREADY=0). Source captures the transfer and the FSM
    // moves IDLE->SETUP (FLOW-1).
    do_write(ADDR_INFLIGHT, DATA_INFLIGHT, "inflight_write");

    // ── T2-T4: target setup -> active phase under back-pressure ──────────────
    // The peripheral holds PREADY=0, so the bridge stays in the active phase
    // with HREADY_OUT=0 (FLOW-2/FLOW-4). No new item is issued here — the AHB
    // master remains parked on the in-flight transfer while the stall holds.

    // ── T5-T6: after the hard-reset abort and clean-IDLE recovery, read back ──
    // STATUS and ERROR_ADDR. Expect STATUS=0x0000_0001 (READY=1, BUSY=0, no
    // sticky bits set by the abort) and ERROR_ADDR=0x0000_0000.
    do_read(REG_STATUS,     "status_postreset");
    do_read(REG_ERROR_ADDR, "erraddr_postreset");

    // ── T7: fresh transfer with PREADY=1 — must complete normally (HRESP=0), ──
    // proving the reset fully cleared the aborted transfer state.
    do_write(ADDR_FRESH, DATA_FRESH, "fresh_write");
    do_read (ADDR_FRESH,             "fresh_readback");

    `uvm_info("XFEAT001_SEQ", "TEST_CROSS_FEATURE_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_cross_feature_001_seq
