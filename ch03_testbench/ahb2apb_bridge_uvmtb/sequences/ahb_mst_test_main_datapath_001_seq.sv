// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_001
// DESCRIPTION: Stimulus for single_transfer_baseline_write.
//              Drives a single (non-sequence) HTRANS=NONSEQ write transfer with
//              HSIZE=word at HADDR=0x0000_1000, HWDATA=0xDEAD_BEEF. This is the
//              sequence-handling baseline: exactly one NONSEQ word write must
//              advance the address correctly and complete as one target access.
//
//              One single word-aligned WRITE transfer:
//                T1: HADDR=0x0000_1000, HWRITE=1, HSIZE=word, HBURST=SINGLE,
//                    HTRANS=NONSEQ, HWDATA=0xDEAD_BEEF
//                    -> PADDR=0x0000_1000, PWRITE=1, PWDATA=0xDEAD_BEEF
//                    -> exactly one PSEL/PENABLE pulse (one target access)
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_001 steps 1-4 — drive one NONSEQ word write and
//     confirm a single target access propagates HADDR/HWDATA to PADDR/PWDATA.
//
// NOTE: No .randomize() — fixed address/data per [TC1].
//
// CONFIDENCE: HIGH — single NONSEQ word write, baseline datapath stimulus.
// =============================================================================

class ahb_mst_test_main_datapath_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_001_seq)

  // Baseline single-transfer address/data corners.
  localparam logic [31:0] DP_ADDR = 32'h0000_1000;
  localparam logic [31:0] DP_DATA = 32'hDEAD_BEEF;

  function new(string name = "ahb_mst_test_main_datapath_001_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP001_SEQ",
      "Starting TEST_MAIN_DATAPATH_001: single NONSEQ word write (baseline)",
      UVM_MEDIUM)

    // Single word WRITE — NONSEQ/New transfer. The bridge must capture HADDR
    // and HWDATA and re-drive them onto PADDR/PWDATA as exactly one APB access.
    req = ahb_mst_seq_item::type_id::create("ahb_dp_wr_0");
    start_item(req);
    req.addr       = DP_ADDR;   // HADDR=0x0000_1000
    req.write      = 1'b1;      // HWRITE=1 (write)
    req.wdata      = DP_DATA;   // HWDATA=0xDEAD_BEEF
    req.trans_type = 2'b10;     // HTRANS=NONSEQ (New)
    req.burst      = 3'b000;    // HBURST=SINGLE
    req.size       = 3'b010;    // HSIZE=word (32-bit)
    req.post_randomize();
    `uvm_info("DP001_SEQ",
      $sformatf("WRITE: HADDR=0x%08h HWDATA=0x%08h (expect PADDR=0x%08h PWDATA=0x%08h)",
                DP_ADDR, DP_DATA, DP_ADDR, DP_DATA), UVM_HIGH)
    finish_item(req);

    `uvm_info("DP001_SEQ", "TEST_MAIN_DATAPATH_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_001_seq
