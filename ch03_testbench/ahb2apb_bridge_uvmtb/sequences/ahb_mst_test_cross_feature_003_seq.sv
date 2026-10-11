// =============================================================================
// FILE: sequences/ahb_mst_test_cross_feature_003_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CROSS_FEATURE_003
// DESCRIPTION: Stimulus for ctrl_register_write_during_active_transfer. Exposes
//              mid-transfer reconfiguration hazards: a CTRL register write that
//              attempts to clear ENABLE is issued WHILE a data write to the APB
//              region is still in flight (peripheral stalls one cycle with
//              PREADY=0 before completing). The in-flight beat must not be
//              corrupted and the CTRL write must apply at a clean boundary.
//
//              All stimulus is issued as raw AHB transactions. Register accesses
//              target the control/status block at PADDR 0xF00..0xF0C; data-plane
//              traffic targets the legal region 0x0000_0000-0x0000_FFFF. The
//              one-cycle stall is produced by the APB slave / tb harness; the
//              scoreboard validates data integrity (PWDATA delivered unchanged,
//              HRESP=0) and that no spurious sticky error is latched.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE bit0, SOFT_RST bit1, reserved 31:8/bit2, ...)
//   STATUS     = 0xF04  (READY b0, BUSY b1, sticky error bits, ...)
//   ERROR_ADDR = 0xF08  (captured faulting address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_CROSS_FEATURE_003 steps T1-T7 — start a stalled data write
//     (0x0000_4000 = 0xCAFE_F00D), issue a concurrent CTRL write clearing
//     ENABLE while the beat is still active, let the original write complete
//     intact (HRESP=0), then read back CTRL (ENABLE=0) and STATUS (no sticky
//     error, BUSY=0, READY=1).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all
//       register accesses are raw AHB transactions to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented flow; checks live in scoreboard.
// =============================================================================

class ahb_mst_test_cross_feature_003_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_cross_feature_003_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL   = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS = 32'h0000_0F04;

  // ── Data-plane address / payload ──────────────────────────────────────────
  localparam logic [31:0] ADDR_DATA  = 32'h0000_4000;  // in-flight write addr
  localparam logic [31:0] DATA_BEAT   = 32'hCAFE_F00D;  // payload that must survive
  localparam logic [31:0] CTRL_CLEAR  = 32'h0000_0000;  // attempt to clear ENABLE

  function new(string name = "ahb_mst_test_cross_feature_003_seq");
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
    `uvm_info("XFEAT003_SEQ",
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
    `uvm_info("XFEAT003_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("XFEAT003_SEQ",
      "Starting TEST_CROSS_FEATURE_003: CTRL register write during active transfer",
      UVM_MEDIUM)

    // ── T1-T3: start the data write that the peripheral stalls (PREADY=0) for ──
    // one cycle before completing. Source captures the write transfer (FLOW-1),
    // target setup -> active phase asserts (FLOW-2), and the bridge holds with
    // HREADY_OUT=0 while the single-cycle back-pressure persists (FLOW-4). The
    // stall and final completion (PREADY=1, PSLVERR=0) are produced by the APB
    // slave / tb harness; the payload 0xCAFE_F00D must reach APB unchanged.
    do_write(ADDR_DATA, DATA_BEAT, "data_beat");

    // ── T4: concurrent CTRL write attempting to clear ENABLE while the data ────
    // transfer is still active. The in-flight beat must not be corrupted; the
    // CTRL write is either deferred or applied without disturbing the active
    // beat (applied at a clean boundary).
    do_write(REG_CTRL, CTRL_CLEAR, "ctrl_clear_enable");

    // ── T6: read back CTRL — expect the write applied at a clean boundary, ─────
    // ENABLE=0, with reserved bits 31:8/bit2 unchanged.
    do_read(REG_CTRL,   "ctrl_readback");

    // ── T7: read back STATUS — expect no sticky error bits set by the ──────────
    // concurrent CTRL access, BUSY=0, READY=1 (STATUS=0x00000001).
    do_read(REG_STATUS, "status_readback");

    `uvm_info("XFEAT003_SEQ", "TEST_CROSS_FEATURE_003 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_cross_feature_003_seq
