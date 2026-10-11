// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_011_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_011
// DESCRIPTION: Stimulus for multi_wait_state_read_data_gating. Drives a single
//              accepted AHB word READ and lets the target-side APB transfer be
//              stalled for multiple cycles by PREADY=0 (the reactive APB slave
//              sequence supplies the wait states). The bridge must hold the APB
//              transfer in the ACTIVE phase while PREADY=0 and only present
//              HRDATA / complete HREADY_OUT when PREADY rises:
//                T1 : HSEL=1, HTRANS=NONSEQ, HWRITE=0,
//                     HADDR=0x0000_2000, HSIZE=word
//              Expected target-side behaviour observed by the monitors:
//                Setup  cycle : PSEL=1, PENABLE=0, PWRITE=0, PADDR=0x0000_2000
//                Active+stall : PSEL=1, PENABLE=1, PREADY=0 — transfer held for
//                               multiple cycles, PADDR stable, HREADY_OUT=0,
//                               HRDATA not yet valid
//                Completion   : PREADY=1, PRDATA=0xA5A5_A5A5 — HREADY_OUT pulses
//                               1, HRDATA=0xA5A5_A5A5 returned, HRESP=0, PENABLE
//                               deasserts the following cycle
//              PENABLE must stay asserted across the whole stall; the address
//              stays stable from setup through the held active phase; the read
//              data is presented to the source ONLY at the cycle PREADY=1.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_011 steps 1-6 — one accepted read whose APB active
//     phase is held by multiple PREADY=0 wait states; HREADY_OUT stays 0 for
//     every PREADY=0 cycle and HRDATA (==PRDATA==0xA5A5_A5A5) is gated to the
//     source only when PREADY=1, with PADDR held stable during the wait.
//
// NOTE: No .randomize() — fixed address per [TC1]. The PREADY wait states and
//       PRDATA are produced by the passive APB slave agent, not driven from this
//       sequence.
//
// CONFIDENCE: HIGH — single fixed-address word read; back-pressure / wait-state
//             data gating is a property of the bridge target FSM observed by the
//             monitors.
// =============================================================================

class ahb_mst_test_main_datapath_011_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_011_seq)

  // Fixed stimulus for the single accepted read under test.
  localparam logic [31:0] DP011_ADDR = 32'h0000_2000;

  function new(string name = "ahb_mst_test_main_datapath_011_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP011_SEQ",
      "Starting TEST_MAIN_DATAPATH_011: single accepted read to exercise multi-cycle PREADY=0 read-data gating",
      UVM_MEDIUM)

    // ── Drive one accepted SINGLE word NONSEQ read ───────────────────────────
    // The bridge takes the APB target from setup (PSEL=1, PENABLE=0, PWRITE=0)
    // into the active phase (PSEL=1, PENABLE=1). With the APB slave holding
    // PREADY=0 for multiple cycles the active phase is held: PADDR=HADDR stays
    // stable, HREADY_OUT stays 0, HRDATA is not yet valid, and the read data
    // (HRDATA=PRDATA=0xA5A5_A5A5, HRESP=0) is presented to the source only once
    // PREADY rises.
    req = ahb_mst_seq_item::type_id::create("ahb_dp011_rd");
    start_item(req);
    req.addr       = DP011_ADDR;  // HADDR=0x0000_2000
    req.write      = 1'b0;        // HWRITE=0 (read)
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word (32-bit)
    `uvm_info("DP011_SEQ",
      $sformatf("READ: HADDR=0x%08h expect HRDATA=0xA5A5A5A5", DP011_ADDR),
      UVM_HIGH)
    finish_item(req);

    `uvm_info("DP011_SEQ", "TEST_MAIN_DATAPATH_011 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_011_seq
