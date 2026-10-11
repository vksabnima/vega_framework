// =============================================================================
// FILE: sequences/ahb_mst_test_bringup_init_003_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_BRINGUP_INIT_003
// DESCRIPTION: Stimulus for single_domain_reset_then_immediate_reuse
//              (single_clock_domain_bringup). With PCLK tied to the HCLK source
//              (PCLK==HCLK), after reset deassertion the bridge returns to a
//              clean IDLE state. This sequence drives a new AHB transfer
//              immediately on the next cycle to prove the bridge accepts a
//              transfer right after reset re-use, then reads back the STATUS
//              register (0xF04) to confirm the BUSY bit.
//
// DERIVED FROM:
//   - XTP TEST_BRINGUP_INIT_003 step 3 — immediately drive a new request:
//     HSEL=0x1, HTRANS=0b10, HWRITE=0x1, HADDR=0x0000_2000, HWDATA=0x0000_DEAD.
//   - XTP TEST_BRINGUP_INIT_003 step 5 — read STATUS (0xF04), verify BUSY bit.
//
// NOTE: No .randomize() — fixed values per [TC1]. Single transfers only.
//       Register access (STATUS @ 0xF04) is a raw AHB read transaction into
//       the register block, per HARD RULES.
//
// CONFIDENCE: HIGH — straightforward single-transfer + register-read stimulus.
// =============================================================================

class ahb_mst_test_bringup_init_003_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_bringup_init_003_seq)

  // Immediate-reuse transfer (XTP step 3).
  localparam logic [31:0] REUSE_ADDR  = 32'h0000_2000;
  localparam logic [31:0] REUSE_WDATA = 32'h0000_DEAD;

  // STATUS register address (XTP step 5).
  localparam logic [31:0] STATUS_ADDR = 32'h0000_0F04;

  function new(string name = "ahb_mst_test_bringup_init_003_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("INIT003_SEQ",
      "Starting TEST_BRINGUP_INIT_003: immediate transfer reuse after reset, then STATUS read",
      UVM_MEDIUM)

    // ── STEP 3 — immediately drive a new request after reset deassert ─────────
    // HSEL=0x1 is implied by an active (NONSEQ) transfer targeting the APB
    // region; PCLK==HCLK so request and PSEL/setup track the same shared edge.
    req = ahb_mst_seq_item::type_id::create("ahb_reuse_wr");
    start_item(req);
    req.addr       = REUSE_ADDR;
    req.write      = 1'b1;    // Write transfer — HWRITE=0x1
    req.wdata      = REUSE_WDATA;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("INIT003_SEQ",
      $sformatf("DRIVE reuse transfer: addr=0x%08h wdata=0x%08h HTRANS=0b%02b",
                req.addr, req.wdata, req.trans_type),
      UVM_HIGH)
    finish_item(req);

    // ── STEP 5 — read STATUS register (0xF04) to verify BUSY bit ──────────────
    // Raw AHB read transaction into the register block per HARD RULES.
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read transfer
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("INIT003_SEQ",
      $sformatf("READ STATUS: addr=0x%08h (expect BUSY bit set)", req.addr),
      UVM_HIGH)
    finish_item(req);

    `uvm_info("INIT003_SEQ", "TEST_BRINGUP_INIT_003 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_bringup_init_003_seq
