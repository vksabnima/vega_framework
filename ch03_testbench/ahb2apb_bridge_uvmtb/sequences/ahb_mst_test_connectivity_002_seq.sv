// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_002_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_002
// DESCRIPTION: Stimulus for source_write_data_bus_connectivity.
//              Verifies the HWDATA write data bus is fully connected by driving
//              walking/boundary data patterns and confirming they appear
//              unchanged on PWDATA (VG2 — write-data propagation, no stuck or
//              shorted data bits).
//
//              Three single word-aligned WRITE transfers:
//                T1/T2: HADDR=0x0000_1000, HWDATA=0xFFFF_FFFF -> PWDATA=0xFFFF_FFFF
//                T3   : HADDR=0x0000_1004, HWDATA=0x0000_0000 -> PWDATA=0x0000_0000
//                T4   : HADDR=0x0000_1008, HWDATA=0xAAAA_AAAA -> PWDATA=0xAAAA_AAAA
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_002 steps 1-5 — drive boundary HWDATA patterns and
//     compare against the PWDATA captured on the peripheral side.
//
// NOTE: No .randomize() — fixed data patterns per [TC1].
//
// CONFIDENCE: HIGH — straightforward boundary write-data connectivity stimulus.
// =============================================================================

class ahb_mst_test_connectivity_002_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_002_seq)

  function new(string name = "ahb_mst_test_connectivity_002_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    logic [31:0] test_addr [3];
    logic [31:0] test_data [3];

    // Word-aligned addresses paired with boundary write-data patterns that
    // exercise every HWDATA bit (all-ones, all-zeros, alternating 1010).
    test_addr[0] = 32'h0000_1000;  test_data[0] = 32'hFFFF_FFFF;
    test_addr[1] = 32'h0000_1004;  test_data[1] = 32'h0000_0000;
    test_addr[2] = 32'h0000_1008;  test_data[2] = 32'hAAAA_AAAA;

    `uvm_info("CONN002_SEQ",
      "Starting TEST_CONNECTIVITY_002: drive boundary HWDATA (0xF..F, 0x0..0, 0xA..A)",
      UVM_MEDIUM)

    // Drive each pattern as a single word WRITE so the bridge captures HWDATA
    // and re-drives it onto PWDATA.
    foreach (test_addr[i]) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_conn_wr_%0d", i));
      start_item(req);
      req.addr       = test_addr[i];
      req.write      = 1'b1;    // Write — step drives HWRITE=1
      req.wdata      = test_data[i];
      req.trans_type = 2'b10;   // NONSEQ — new transfer
      req.burst      = 3'b000;  // SINGLE
      req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
      req.post_randomize();
      `uvm_info("CONN002_SEQ",
        $sformatf("WRITE data-pattern[%0d]: HADDR=0x%08h HWDATA=0x%08h (expect PWDATA=0x%08h)",
                  i, test_addr[i], test_data[i], test_data[i]), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("CONN002_SEQ", "TEST_CONNECTIVITY_002 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_002_seq
