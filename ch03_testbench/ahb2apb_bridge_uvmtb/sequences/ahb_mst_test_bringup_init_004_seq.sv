// =============================================================================
// FILE: sequences/ahb_mst_test_bringup_init_004_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_BRINGUP_INIT_004
// DESCRIPTION: Stimulus for single_clock_domain_no_cdc_assumption
//              (single_clock_domain_bringup). PCLK is tied to the HCLK source
//              (single clock domain), so no CDC handling (synchronizers, async
//              resets) is exercised. This sequence drives a single AHB write to
//              HADDR=0x0000_3000 and observes deterministic single-cycle
//              propagation to PADDR, then reads the SAME address back so that
//              HRDATA can be checked against PRDATA on the shared clock edge
//              with no synchronizer pipeline delay (zero CDC latency).
//
// DERIVED FROM:
//   - XTP TEST_BRINGUP_INIT_004 step 2 — drive HSEL=0x1, HTRANS=0b10,
//     HADDR=0x0000_3000 and observe PADDR=0x0000_3000 (single-cycle align).
//   - XTP TEST_BRINGUP_INIT_004 step 4 — HRDATA captured from PRDATA without
//     any synchronizer pipeline delay (same clock domain edge).
//
// NOTE: No .randomize() — fixed values per [TC1]. Single transfers only.
//       Single clock domain: PCLK==HCLK, no async/CDC stimulus required.
//
// CONFIDENCE: HIGH — straightforward single-transfer write + read-back stimulus.
// =============================================================================

class ahb_mst_test_bringup_init_004_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_bringup_init_004_seq)

  // Single-clock-domain propagation transfer (XTP step 2).
  localparam logic [31:0] CDC_ADDR  = 32'h0000_3000;
  localparam logic [31:0] CDC_WDATA = 32'h0000_C0DE;

  function new(string name = "ahb_mst_test_bringup_init_004_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("INIT004_SEQ",
      "Starting TEST_BRINGUP_INIT_004: single clock domain, no CDC — write to 0x3000 then read back",
      UVM_MEDIUM)

    // ── STEP 2 — drive a write to HADDR=0x0000_3000, observe PADDR propagation ─
    // HSEL=0x1 is implied by an active (NONSEQ) transfer targeting the APB
    // region; PCLK==HCLK so HADDR -> PADDR aligns on the same shared edge with
    // no metastability window.
    req = ahb_mst_seq_item::type_id::create("ahb_cdc_wr");
    start_item(req);
    req.addr       = CDC_ADDR;
    req.write      = 1'b1;    // Write transfer — HWRITE=0x1
    req.wdata      = CDC_WDATA;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("INIT004_SEQ",
      $sformatf("DRIVE write: addr=0x%08h wdata=0x%08h HTRANS=0b%02b (expect PADDR=0x%08h)",
                req.addr, req.wdata, req.trans_type, req.addr),
      UVM_HIGH)
    finish_item(req);

    // ── STEP 4 — read the SAME address; HRDATA captured from PRDATA on the ─────
    // same clock-domain edge with no synchronizer pipeline delay.
    req = ahb_mst_seq_item::type_id::create("ahb_cdc_rd");
    start_item(req);
    req.addr       = CDC_ADDR;
    req.write      = 1'b0;    // Read transfer
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("INIT004_SEQ",
      $sformatf("READ back: addr=0x%08h (expect HRDATA==PRDATA on same edge)", req.addr),
      UVM_HIGH)
    finish_item(req);

    `uvm_info("INIT004_SEQ", "TEST_BRINGUP_INIT_004 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_bringup_init_004_seq
