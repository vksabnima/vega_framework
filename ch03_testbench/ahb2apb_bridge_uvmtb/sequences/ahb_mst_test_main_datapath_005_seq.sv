// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_005_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_005
// DESCRIPTION: Stimulus for basic_write_translation.
//              Drives a single source-side word write and then reads the same
//              address back to confirm the 1:1 datapath mapping through the
//              bridge:
//                WRITE: HADDR=0x0000_1000 HWRITE=1 HWDATA=0xDEAD_BEEF
//                       HTRANS=NONSEQ HBURST=SINGLE HSIZE=word
//                READ : HADDR=0x0000_1000 HWRITE=0 — expect HRDATA=0xDEAD_BEEF
//              The bridge must capture the source-side address/control/payload
//              (FLOW-1), drive the target setup phase PSEL=1/PENABLE=0 (FLOW-2),
//              the active phase PSEL=1/PENABLE=1 with PREADY=1 (FLOW-3), and
//              complete with HRESP=0/HREADY_OUT=1 (FLOW-5). PADDR==HADDR and
//              PWDATA==HWDATA confirm the 1:1 transfer mapping.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_005 steps 1-6 — single source-side write
//     HADDR=0x0000_1000 / HWDATA=0xDEAD_BEEF translated to a target write with
//     PADDR=0x0000_1000 / PWDATA=0xDEAD_BEEF; read-back confirms data integrity.
//
// NOTE: No .randomize() — fixed address/data per [TC1].
//
// CONFIDENCE: HIGH — single fixed word write then read-back, basic datapath.
// =============================================================================

class ahb_mst_test_main_datapath_005_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_005_seq)

  // Single-transfer write target — word-aligned address and fixed payload.
  localparam logic [31:0] DP_ADDR = 32'h0000_1000;
  localparam logic [31:0] DP_DATA = 32'hDEAD_BEEF;

  function new(string name = "ahb_mst_test_main_datapath_005_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP005_SEQ",
      "Starting TEST_MAIN_DATAPATH_005: single word write then read-back",
      UVM_MEDIUM)

    // ── PHASE 1 — single source-side WRITE (FLOW-1 capture) ──────────────────
    // Drive HADDR=0x0000_1000, HWRITE=1, HWDATA=0xDEAD_BEEF as a SINGLE word
    // NONSEQ transfer. The bridge must translate this 1:1 onto the target side
    // producing PADDR=0x0000_1000 / PWDATA=0xDEAD_BEEF.
    req = ahb_mst_seq_item::type_id::create("ahb_dp005_wr");
    start_item(req);
    req.addr       = DP_ADDR;     // HADDR=0x0000_1000
    req.write      = 1'b1;        // HWRITE=1 (write)
    req.wdata      = DP_DATA;     // HWDATA=0xDEAD_BEEF
    req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word (32-bit)
    `uvm_info("DP005_SEQ",
      $sformatf("WRITE: HADDR=0x%08h HWDATA=0x%08h (expect PADDR=0x%08h PWDATA=0x%08h)",
                DP_ADDR, DP_DATA, DP_ADDR, DP_DATA), UVM_HIGH)
    finish_item(req);

    // ── PHASE 2 — READ-back of the same address (confirm 1:1 mapping) ─────────
    // The APB slave memory model returns the value stored by the write above,
    // so the read should return 0xDEAD_BEEF unchanged on HRDATA with HRESP=0.
    req = ahb_mst_seq_item::type_id::create("ahb_dp005_rd");
    start_item(req);
    req.addr       = DP_ADDR;     // HADDR=0x0000_1000
    req.write      = 1'b0;        // HWRITE=0 (read)
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word (32-bit)
    `uvm_info("DP005_SEQ",
      $sformatf("READ: HADDR=0x%08h expect HRDATA=0x%08h", DP_ADDR, DP_DATA), UVM_HIGH)
    finish_item(req);

    `uvm_info("DP005_SEQ", "TEST_MAIN_DATAPATH_005 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_005_seq
