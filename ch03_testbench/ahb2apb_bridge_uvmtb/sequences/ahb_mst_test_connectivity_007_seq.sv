// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_007_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_007
// DESCRIPTION: Stimulus for pwdata_data_bus_connectivity.
//              Verifies PWDATA correctly carries walking/boundary data patterns
//              from the source side to the peripheral side, proving no PWDATA
//              bit is stuck/shorted. Four source-side write transfers are driven
//              on AHB to HADDR=0x0000_1000:
//                WRITE all-ones (HWDATA=0xFFFF_FFFF) — expect PWDATA=0xFFFF_FFFF
//                WRITE all-zero (HWDATA=0x0000_0000) — expect PWDATA=0x0000_0000
//                WRITE walking  (HWDATA=0xAAAA_AAAA) — expect PWDATA=0xAAAA_AAAA
//                WRITE walking  (HWDATA=0x5555_5555) — expect PWDATA=0x5555_5555
//              The SETUP (PSEL=1, PENABLE=0) and ACTIVE (PSEL=1, PENABLE=1,
//              PWRITE=1) phase sampling and the PWDATA==HWDATA comparison are
//              performed by the monitors/scoreboard; this sequence supplies the
//              stimulus.
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_007 steps 1-6 — drive HWDATA=0xFFFF_FFFF,
//     0x0000_0000, 0xAAAA_AAAA, 0x5555_5555 with HWRITE=1, HSEL=1,
//     HTRANS=2'b10 (NONSEQ) to HADDR=0x0000_1000, confirm PWDATA propagates
//     each value with no stuck/shorted bits (pages page 8).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. SETUP/ACTIVE phase
//       observation is done by the monitors, not this sequence.
//
// CONFIDENCE: HIGH — straightforward walking/boundary data connectivity stimulus.
// =============================================================================

class ahb_mst_test_connectivity_007_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_007_seq)

  function new(string name = "ahb_mst_test_connectivity_007_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    // Walking/boundary data connectivity patterns — same address, four payloads
    logic [31:0] test_data [4];
    int unsigned i;

    test_data[0] = 32'hFFFF_FFFF;  // all-ones boundary
    test_data[1] = 32'h0000_0000;  // all-zero boundary
    test_data[2] = 32'hAAAA_AAAA;  // walking pattern (even bits)
    test_data[3] = 32'h5555_5555;  // walking pattern (odd bits)

    `uvm_info("CONN007_SEQ",
      "Starting TEST_CONNECTIVITY_007: PWDATA walking/boundary data bus connectivity",
      UVM_MEDIUM)

    // ── Steps 1-5 — drive four write transfers to HADDR=0x0000_1000 ──────────
    // Each is a source-side write (HWRITE=1, HSEL=1, HTRANS=2'b10) that the
    // bridge must propagate to PWDATA unchanged across SETUP and ACTIVE phases.
    for (i = 0; i < 4; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_conn007_wr_%0d", i));
      start_item(req);
      req.addr       = 32'h0000_1000;  // fixed source address per XTP steps
      req.write      = 1'b1;           // Write — drive HSEL=1, HTRANS=2'b10
      req.wdata      = test_data[i];
      req.trans_type = 2'b10;          // NONSEQ — new transfer
      req.burst      = 3'b000;         // SINGLE
      req.size       = 3'b010;         // Word (32-bit)
      req.post_randomize();
      `uvm_info("CONN007_SEQ",
        $sformatf("WRITE[%0d]: HADDR=0x0000_1000 HWDATA=0x%08h (expect PWDATA=0x%08h, no stuck bits)",
                  i, test_data[i], test_data[i]), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("CONN007_SEQ", "TEST_CONNECTIVITY_007 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_007_seq
