// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_003_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_003
// DESCRIPTION: Stimulus for source_read_data_loopback_verify.
//              Drives a WRITE followed by a READ of the SAME address and
//              confirms the read returns the written data through HRDATA,
//              proving read-data bus connectivity and write/read correspondence
//              (VG2 write propagation + VG3 read-data returned unchanged).
//
//              Two single word-aligned transfers:
//                T1/T2: WRITE HADDR=0x0000_2000, HWDATA=0xAAAA_AAAA
//                       -> PWDATA=0xAAAA_AAAA stored at PADDR
//                T3/T4/T5: READ HADDR=0x0000_2000
//                       -> PRDATA=0xAAAA_AAAA -> HRDATA=0xAAAA_AAAA
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_003 steps 1-5 — write then read-back loopback;
//     HRDATA on the read must equal the value written.
//
// NOTE: No .randomize() — fixed data pattern per [TC1].
//
// CONFIDENCE: HIGH — straightforward write/read-back loopback stimulus.
// =============================================================================

class ahb_mst_test_connectivity_003_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_003_seq)

  function new(string name = "ahb_mst_test_connectivity_003_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    logic [31:0] test_addr = 32'h0000_2000;
    logic [31:0] test_data = 32'hAAAA_AAAA;

    `uvm_info("CONN003_SEQ",
      "Starting TEST_CONNECTIVITY_003: write 0xAAAA_AAAA then read-back loopback",
      UVM_MEDIUM)

    // ── T1/T2 — WRITE 0xAAAA_AAAA to 0x0000_2000 ────────────────────────────
    // Bridge captures HWDATA and re-drives it onto PWDATA; APB slave stores it.
    req = ahb_mst_seq_item::type_id::create("ahb_conn003_wr");
    start_item(req);
    req.addr       = test_addr;
    req.write      = 1'b1;    // Write — step drives HWRITE=1
    req.wdata      = test_data;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("CONN003_SEQ",
      $sformatf("WRITE: HADDR=0x%08h HWDATA=0x%08h (expect PWDATA=0x%08h stored)",
                test_addr, test_data, test_data), UVM_HIGH)
    finish_item(req);

    // ── T3/T4/T5 — READ back the SAME address ───────────────────────────────
    // APB slave returns the stored value on PRDATA; bridge forwards it onto
    // HRDATA only after target completion. Expect HRDATA == written value.
    req = ahb_mst_seq_item::type_id::create("ahb_conn003_rd");
    start_item(req);
    req.addr       = test_addr;
    req.write      = 1'b0;    // Read — step drives HWRITE=0
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("CONN003_SEQ",
      $sformatf("READ: HADDR=0x%08h (expect HRDATA=0x%08h)", test_addr, test_data),
      UVM_HIGH)
    finish_item(req);

    `uvm_info("CONN003_SEQ", "TEST_CONNECTIVITY_003 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_003_seq
