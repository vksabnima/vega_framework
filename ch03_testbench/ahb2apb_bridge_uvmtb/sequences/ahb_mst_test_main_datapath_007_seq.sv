// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_007_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_007
// DESCRIPTION: Stimulus for data_pattern_integrity. Drives four single-word AHB
//              writes carrying the classic data-integrity bit patterns and checks
//              (via scoreboard) that each HWDATA reaches the APB side as PWDATA
//              bit-for-bit, with PADDR==HADDR and a 1:1 write mapping:
//                T1 : HADDR=0x0000_3000 HWDATA=0xFFFF_FFFF (all ones)
//                T2 : HADDR=0x0000_3004 HWDATA=0x0000_0000 (all zeros)
//                T3 : HADDR=0x0000_3008 HWDATA=0xAAAA_AAAA (alternating)
//                T4 : HADDR=0x0000_300C HWDATA=0x5555_5555 (alternating inverse)
//              Each transfer is HSEL=1, HTRANS=NONSEQ, HWRITE=1, SINGLE, word.
//              The bridge must translate each source-side write 1:1 onto the
//              target side (PSEL=1/PENABLE=1, PWRITE=1, PADDR=HADDR, PWDATA=HWDATA)
//              and complete with HRESP=0/HREADY_OUT=1.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_007 steps 1-6 — four word writes covering all-ones,
//     all-zeros and both alternating patterns; PWDATA must equal HWDATA with no
//     bit corruption and PADDR must equal HADDR for each transfer.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — four fixed-pattern single word writes, basic datapath.
// =============================================================================

class ahb_mst_test_main_datapath_007_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_007_seq)

  // Word-aligned target addresses and the four data-integrity bit patterns.
  localparam int unsigned NUM_PAT = 4;

  function new(string name = "ahb_mst_test_main_datapath_007_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    logic [31:0] pat_addr [NUM_PAT];
    logic [31:0] pat_data [NUM_PAT];
    int unsigned i;

    // Pattern table — address paired with the data pattern it carries.
    pat_addr[0] = 32'h0000_3000;  pat_data[0] = 32'hFFFF_FFFF;  // all ones
    pat_addr[1] = 32'h0000_3004;  pat_data[1] = 32'h0000_0000;  // all zeros
    pat_addr[2] = 32'h0000_3008;  pat_data[2] = 32'hAAAA_AAAA;  // alternating
    pat_addr[3] = 32'h0000_300C;  pat_data[3] = 32'h5555_5555;  // alternating inverse

    `uvm_info("DP007_SEQ",
      "Starting TEST_MAIN_DATAPATH_007: four word writes (data pattern integrity)",
      UVM_MEDIUM)

    // ── Drive each pattern as a SINGLE word NONSEQ write ─────────────────────
    // The bridge must propagate HWDATA->PWDATA bit-exactly and HADDR->PADDR for
    // each of the four patterns, completing every write with HRESP=0.
    for (i = 0; i < NUM_PAT; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp007_wr_%0d", i));
      start_item(req);
      req.addr       = pat_addr[i];  // HADDR
      req.write      = 1'b1;         // HWRITE=1 (write)
      req.wdata      = pat_data[i];  // HWDATA pattern under test
      req.trans_type = 2'b10;        // HTRANS=NONSEQ (new transfer)
      req.burst      = 3'b000;       // HBURST=SINGLE
      req.size       = 3'b010;       // HSIZE=word (32-bit)
      `uvm_info("DP007_SEQ",
        $sformatf("WRITE[%0d]: HADDR=0x%08h HWDATA=0x%08h", i, pat_addr[i], pat_data[i]),
        UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("DP007_SEQ", "TEST_MAIN_DATAPATH_007 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_007_seq
