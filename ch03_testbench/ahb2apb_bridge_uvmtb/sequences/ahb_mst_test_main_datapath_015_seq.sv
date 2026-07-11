// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_015_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_015
// DESCRIPTION: Stimulus for read_data_blocked_until_target_completion. Drives a
//              single accepted AHB word READ and lets the target-side APB
//              transfer be stalled by PREADY=0 (the reactive APB slave sequence
//              supplies the wait states). The bridge must NOT return HRDATA and
//              must gate source completion (HREADY_OUT=0) while the target is
//              stalled, then return the correct read data once PREADY asserts:
//                T1 : HSEL=1, HTRANS=NONSEQ, HWRITE=0,
//                     HADDR=0x0000_2000, HREADY_IN=1
//              Expected target-side behaviour observed by the monitors:
//                Setup  cycle : PSEL=1, PENABLE=0, PWRITE=0, PADDR=0x0000_2000,
//                               HRDATA invalid
//                Active+stall : PSEL=1, PENABLE=1, PREADY=0 — completion held,
//                               HREADY_OUT=0, HRDATA NOT driven, STATUS.BUSY=1
//                Completion   : PREADY=1, PRDATA=0xA5A5_5A5A, PSLVERR=0 —
//                               HREADY_OUT pulses 1, HRESP=0, HRDATA=0xA5A5_5A5A
//              HRDATA is held off during the stall and only returned once the
//              target completes; read data return strictly follows target
//              completion.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_015 steps 1-6 — one accepted read whose APB active
//     phase is held by PREADY=0; HREADY_OUT stays 0 and HRDATA is not updated
//     for every PREADY=0 cycle, then HRDATA=0xA5A5_5A5A is returned with HRESP=0
//     once PREADY=1.
//
// NOTE: No .randomize() — fixed address per [TC1]. The PREADY wait state and the
//       PRDATA value are produced by the passive APB slave agent, not driven
//       from this sequence.
//
// CONFIDENCE: HIGH — single fixed-address word read; read-data gating during the
//             wait state is a property of the bridge target FSM observed by the
//             monitors.
// =============================================================================

class ahb_mst_test_main_datapath_015_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_015_seq)

  // Fixed stimulus for the single accepted read under test.
  localparam logic [31:0] DP015_ADDR = 32'h0000_2000;

  function new(string name = "ahb_mst_test_main_datapath_015_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP015_SEQ",
      "Starting TEST_MAIN_DATAPATH_015: single accepted read; HRDATA must be gated until target completes (PREADY=1)",
      UVM_MEDIUM)

    // ── Drive one accepted SINGLE word NONSEQ read ───────────────────────────
    // The bridge takes the APB target from setup (PSEL=1, PENABLE=0, PWRITE=0)
    // into the active phase (PSEL=1, PENABLE=1). With the APB slave holding
    // PREADY=0 the active phase is held: HREADY_OUT stays 0 and HRDATA is NOT
    // driven to the source. Completion (HRESP=0 / HREADY_OUT=1 /
    // HRDATA=0xA5A5_5A5A) only occurs once PREADY rises with PRDATA valid.
    req = ahb_mst_seq_item::type_id::create("ahb_dp015_rd");
    start_item(req);
    req.addr       = DP015_ADDR;  // HADDR=0x0000_2000
    req.write      = 1'b0;        // HWRITE=0 (read)
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word (32-bit)
    `uvm_info("DP015_SEQ",
      $sformatf("READ: HADDR=0x%08h (expect HRDATA=0xA5A5_5A5A only after PREADY=1)", DP015_ADDR),
      UVM_HIGH)
    finish_item(req);

    `uvm_info("DP015_SEQ", "TEST_MAIN_DATAPATH_015 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_015_seq
