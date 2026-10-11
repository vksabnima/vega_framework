// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_008_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_008
// DESCRIPTION: Stimulus for prdata_read_path_connectivity.
//              Verifies peripheral read data on PRDATA is correctly returned to
//              the source side and that read-back HRDATA matches the value placed
//              on PRDATA, proving the read data path connectivity with no stuck
//              bits. Three source-side read transfers are driven on AHB to
//              HADDR=0x0000_2000:
//                READ #1 — expect HRDATA=0xDEAD_BEEF (PRDATA driven by peripheral)
//                READ #2 — expect HRDATA=0x0000_0000 (all-zero boundary)
//                READ #3 — expect HRDATA=0xFFFF_FFFF (all-ones boundary)
//              The bridge enters peripheral SETUP (PSEL=1, PENABLE=0, PWRITE=0)
//              then ACTIVE (PSEL=1, PENABLE=1) where the peripheral presents
//              PRDATA with PREADY=1; the captured HRDATA==PRDATA comparison and
//              HRESP=0 / HREADY_OUT=1 checks are performed by the monitors/
//              scoreboard. This sequence supplies the read stimulus.
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_008 steps 1-6 — issue read transfers (HWRITE=0,
//     HSEL=1, HTRANS=2'b10 NONSEQ) to HADDR=0x0000_2000 and confirm HRDATA
//     exactly equals the PRDATA value (0xDEAD_BEEF, 0x0000_0000, 0xFFFF_FFFF)
//     returned only after PENABLE=1 and PREADY=1 (pages page 8).
//
// NOTE: No .randomize() — fixed address/data per [TC1]. SETUP/ACTIVE phase
//       observation and PRDATA→HRDATA comparison are done by the monitors,
//       not this sequence. The peripheral-side PRDATA values are produced by
//       the reactive APB slave model.
//
// CONFIDENCE: HIGH — straightforward read data path connectivity stimulus.
// =============================================================================

class ahb_mst_test_connectivity_008_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_008_seq)

  function new(string name = "ahb_mst_test_connectivity_008_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    // Expected PRDATA values to be returned on the read data path (HRDATA).
    logic [31:0] expect_data [3];
    int unsigned i;

    expect_data[0] = 32'hDEAD_BEEF;  // distinctive read payload
    expect_data[1] = 32'h0000_0000;  // all-zero boundary
    expect_data[2] = 32'hFFFF_FFFF;  // all-ones boundary

    `uvm_info("CONN008_SEQ",
      "Starting TEST_CONNECTIVITY_008: PRDATA read data path connectivity",
      UVM_MEDIUM)

    // ── Steps 1-5 — drive three read transfers to HADDR=0x0000_2000 ──────────
    // Each is a source-side read (HWRITE=0, HSEL=1, HTRANS=2'b10) that the
    // bridge maps to a peripheral read; the peripheral returns PRDATA in the
    // ACTIVE phase (PENABLE=1, PREADY=1) and that value must appear on HRDATA.
    for (i = 0; i < 3; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_conn008_rd_%0d", i));
      start_item(req);
      req.addr       = 32'h0000_2000;  // fixed source address per XTP steps
      req.write      = 1'b0;           // Read — drive HSEL=1, HTRANS=2'b10
      req.wdata      = 32'h0;          // unused for reads
      req.trans_type = 2'b10;          // NONSEQ — new transfer
      req.burst      = 3'b000;         // SINGLE
      req.size       = 3'b010;         // Word (32-bit)
      req.post_randomize();
      `uvm_info("CONN008_SEQ",
        $sformatf("READ[%0d]: HADDR=0x0000_2000 (expect HRDATA=PRDATA=0x%08h, HRESP=0, no stuck bits)",
                  i, expect_data[i]), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("CONN008_SEQ", "TEST_CONNECTIVITY_008 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_008_seq
