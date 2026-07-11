// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_014_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_014
// DESCRIPTION: Stimulus for basic_single_read_data_return.
//              Drives a single (non-sequence) HTRANS=NONSEQ read transfer with
//              HSIZE=word at HADDR=0x0000_1000. The bridge must run the target
//              (APB) setup then active phase, capture PRDATA, and only return it
//              on HRDATA once the target active phase completes (PREADY=1).
//
//              One single word-aligned READ transfer:
//                T1: HADDR=0x0000_1000, HWRITE=0, HSIZE=word, HBURST=SINGLE,
//                    HTRANS=NONSEQ, HREADY_IN=1
//                    -> PSEL=1/PENABLE=0 setup, then PENABLE=1 active
//                    -> PRDATA=0xDEAD_BEEF captured on PREADY=1
//                    -> HRDATA=0xDEAD_BEEF returned only at HREADY_OUT=1 (T4)
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_014 steps 1-5 — drive one NONSEQ word read and
//     confirm PRDATA returns on HRDATA only after the target active phase
//     completes (read_data_return_path, spec pages 9-10).
//
// NOTE: No .randomize() — fixed address per [TC1]. The APB slave memory model
//       supplies PRDATA; this sequence only drives the AHB read request.
//
// CONFIDENCE: HIGH — single NONSEQ word read, baseline read-return stimulus.
// =============================================================================

class ahb_mst_test_main_datapath_014_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_014_seq)

  // Baseline single-transfer read address.
  localparam logic [31:0] DP_ADDR = 32'h0000_1000;

  function new(string name = "ahb_mst_test_main_datapath_014_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP014_SEQ",
      "Starting TEST_MAIN_DATAPATH_014: single NONSEQ word read (data return)",
      UVM_MEDIUM)

    // Single word READ — NONSEQ/New transfer. The bridge runs the target setup
    // then active phase, captures PRDATA, and re-drives it onto HRDATA only once
    // the target completes (PREADY=1 -> HREADY_OUT=1).
    req = ahb_mst_seq_item::type_id::create("ahb_dp_rd_0");
    start_item(req);
    req.addr       = DP_ADDR;   // HADDR=0x0000_1000
    req.write      = 1'b0;      // HWRITE=0 (read)
    req.wdata      = 32'h0;     // unused for reads
    req.trans_type = 2'b10;     // HTRANS=NONSEQ (New)
    req.burst      = 3'b000;    // HBURST=SINGLE
    req.size       = 3'b010;    // HSIZE=word (32-bit)
    req.post_randomize();
    `uvm_info("DP014_SEQ",
      $sformatf("READ: HADDR=0x%08h (expect HRDATA returns from PRDATA at HREADY_OUT=1)",
                DP_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("DP014_SEQ", "TEST_MAIN_DATAPATH_014 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_014_seq
