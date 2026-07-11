// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_010_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_010
// DESCRIPTION: Stimulus for single_wait_state_delays_completion. Drives a single
//              accepted AHB word write and lets the target-side APB transfer be
//              stalled for one cycle by PREADY=0 (the reactive APB slave
//              sequence supplies the wait state). The bridge must hold the APB
//              transfer in the ACTIVE phase while PREADY=0 and only complete
//              HREADY_OUT when PREADY rises:
//                T1 : HSEL=1, HTRANS=NONSEQ, HWRITE=1,
//                     HADDR=0x0000_1000, HWDATA=0xDEAD_BEEF
//              Expected target-side behaviour observed by the monitors:
//                Setup  cycle : PSEL=1, PENABLE=0, PADDR=0x0000_1000,
//                               PWDATA=0xDEAD_BEEF
//                Active+stall : PSEL=1, PENABLE=1, PREADY=0 — transfer held,
//                               PADDR/PWDATA stable, HREADY_OUT=0
//                Completion   : PREADY=1 — HREADY_OUT pulses 1, HRESP=0,
//                               PENABLE deasserts the following cycle
//              PENABLE must stay asserted across the whole stall; address/data
//              stay stable from setup through the held active phase.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_010 steps 1-6 — one accepted write whose APB
//     active phase is held by a single PREADY=0 wait state; HREADY_OUT stays 0
//     for every PREADY=0 cycle and pulses 1 only when PREADY=1, with
//     PADDR/PWDATA held stable during the wait.
//
// NOTE: No .randomize() — fixed address/data per [TC1]. The PREADY wait state is
//       produced by the passive APB slave agent, not driven from this sequence.
//
// CONFIDENCE: HIGH — single fixed-address word write; back-pressure / wait-state
//             handling is a property of the bridge target FSM observed by the
//             monitors.
// =============================================================================

class ahb_mst_test_main_datapath_010_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_010_seq)

  // Fixed stimulus for the single accepted write under test.
  localparam logic [31:0] DP010_ADDR = 32'h0000_1000;
  localparam logic [31:0] DP010_DATA = 32'hDEAD_BEEF;

  function new(string name = "ahb_mst_test_main_datapath_010_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP010_SEQ",
      "Starting TEST_MAIN_DATAPATH_010: single accepted write to exercise a single PREADY=0 wait state",
      UVM_MEDIUM)

    // ── Drive one accepted SINGLE word NONSEQ write ──────────────────────────
    // The bridge takes the APB target from setup (PSEL=1, PENABLE=0) into the
    // active phase (PSEL=1, PENABLE=1). With the APB slave holding PREADY=0 for
    // one cycle the active phase is held: PADDR=HADDR and PWDATA=HWDATA stay
    // stable, HREADY_OUT stays 0, and completion (HRESP=0 / HREADY_OUT=1) only
    // occurs once PREADY rises.
    req = ahb_mst_seq_item::type_id::create("ahb_dp010_wr");
    start_item(req);
    req.addr       = DP010_ADDR;  // HADDR=0x0000_1000
    req.write      = 1'b1;        // HWRITE=1 (write)
    req.wdata      = DP010_DATA;  // HWDATA=0xDEAD_BEEF
    req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word (32-bit)
    `uvm_info("DP010_SEQ",
      $sformatf("WRITE: HADDR=0x%08h HWDATA=0x%08h", DP010_ADDR, DP010_DATA),
      UVM_HIGH)
    finish_item(req);

    `uvm_info("DP010_SEQ", "TEST_MAIN_DATAPATH_010 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_010_seq
