// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_009_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_009
// DESCRIPTION: Stimulus for phase_progression_setup_to_active. Drives a single
//              accepted AHB word write and lets the target-side two-phase APB
//              progression be observed by the monitors / scoreboard:
//                T1 : HSEL=1, HTRANS=NONSEQ, HWRITE=1,
//                     HADDR=0x0000_1000, HWDATA=0xDEAD_BEEF
//              The bridge must drive the APB target through the strict
//              setup-then-active progression:
//                Setup  cycle : PSEL=1, PENABLE=0, PADDR=0x0000_1000,
//                               PWDATA=0xDEAD_BEEF
//                Active cycle : PSEL=1, PENABLE=1, PADDR/PWDATA held stable
//                Completion   : PSEL=0, PENABLE=0, HREADY_OUT=1, HRESP=0
//              PENABLE must never be asserted in the same cycle PSEL is first
//              asserted; address/data stay stable from setup through active.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_009 steps 1-5 — one accepted write drives the
//     target-side setup->active->idle progression; PENABLE deasserted during
//     the first (setup) PSEL cycle and asserted only in the following (active)
//     cycle while PSEL stays 1, with PADDR/PWDATA stable across both phases.
//
// NOTE: No .randomize() — fixed address/data per [TC1].
//
// CONFIDENCE: HIGH — single fixed-address word write; phase progression is a
//             property of the bridge target FSM observed by the monitors.
// =============================================================================

class ahb_mst_test_main_datapath_009_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_009_seq)

  // Fixed stimulus for the single accepted write under test.
  localparam logic [31:0] DP009_ADDR = 32'h0000_1000;
  localparam logic [31:0] DP009_DATA = 32'hDEAD_BEEF;

  function new(string name = "ahb_mst_test_main_datapath_009_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP009_SEQ",
      "Starting TEST_MAIN_DATAPATH_009: single accepted write to exercise setup->active phase progression",
      UVM_MEDIUM)

    // ── Drive one accepted SINGLE word NONSEQ write ──────────────────────────
    // The bridge must take the APB target from setup (PSEL=1, PENABLE=0)
    // through active (PSEL=1, PENABLE=1) back to idle (PSEL=0, PENABLE=0),
    // holding PADDR=HADDR and PWDATA=HWDATA stable across both phases and
    // completing with HRESP=0 / HREADY_OUT=1.
    req = ahb_mst_seq_item::type_id::create("ahb_dp009_wr");
    start_item(req);
    req.addr       = DP009_ADDR;  // HADDR=0x0000_1000
    req.write      = 1'b1;        // HWRITE=1 (write)
    req.wdata      = DP009_DATA;  // HWDATA=0xDEAD_BEEF
    req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word (32-bit)
    `uvm_info("DP009_SEQ",
      $sformatf("WRITE: HADDR=0x%08h HWDATA=0x%08h", DP009_ADDR, DP009_DATA),
      UVM_HIGH)
    finish_item(req);

    `uvm_info("DP009_SEQ", "TEST_MAIN_DATAPATH_009 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_009_seq
