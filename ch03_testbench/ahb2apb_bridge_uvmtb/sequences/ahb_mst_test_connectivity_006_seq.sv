// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_006_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_006
// DESCRIPTION: Stimulus for paddr_address_bus_connectivity.
//              Verifies PADDR drives both the minimum (0x0000_0000) and the
//              maximum (0xFFFF_FFFF) address values correctly through the
//              peripheral-side interface, proving no PADDR bit is stuck/tied.
//              Two source-side write transfers are driven on AHB:
//                WRITE min  (HADDR=0x0000_0000) — expect PADDR=0x0000_0000
//                WRITE max  (HADDR=0xFFFF_FFFF) — expect PADDR=0xFFFF_FFFF
//              The SETUP (PSEL=1, PENABLE=0) and ACTIVE (PSEL=1, PENABLE=1)
//              phase sampling and the PADDR==HADDR comparison are performed by
//              the monitors/scoreboard; this sequence supplies the stimulus.
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_006 steps 1-6 — drive HADDR=0x0000_0000 then
//     HADDR=0xFFFF_FFFF with HWRITE=1, HSEL=1, HTRANS=2'b10 (NONSEQ), confirm
//     PADDR propagates each value with no stuck bits (pages page 8).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. SETUP/ACTIVE phase
//       observation is done by the monitors, not this sequence.
//
// CONFIDENCE: HIGH — straightforward min/max address connectivity stimulus.
// =============================================================================

class ahb_mst_test_connectivity_006_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_006_seq)

  function new(string name = "ahb_mst_test_connectivity_006_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    // Min/max address connectivity stimulus
    logic [31:0] test_addr [2];
    logic [31:0] test_data [2];
    int unsigned i;

    test_addr[0] = 32'h0000_0000; test_data[0] = 32'h0000_0000;  // min address
    test_addr[1] = 32'hFFFF_FFFF; test_data[1] = 32'hFFFF_FFFF;  // max address

    `uvm_info("CONN006_SEQ",
      "Starting TEST_CONNECTIVITY_006: PADDR min/max address bus connectivity",
      UVM_MEDIUM)

    // ── Steps 1-5 — drive min then max address write transfers ──────────────
    // Each is a source-side write (HWRITE=1, HSEL=1, HTRANS=2'b10) that the
    // bridge must propagate to PADDR unchanged across SETUP and ACTIVE phases.
    for (i = 0; i < 2; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_conn006_wr_%0d", i));
      start_item(req);
      req.addr       = test_addr[i];
      req.write      = 1'b1;    // Write — drive HSEL=1, HTRANS=2'b10, HADDR
      req.wdata      = test_data[i];
      req.trans_type = 2'b10;   // NONSEQ — new transfer
      req.burst      = 3'b000;  // SINGLE
      req.size       = 3'b010;  // Word (32-bit)
      req.post_randomize();
      `uvm_info("CONN006_SEQ",
        $sformatf("WRITE[%0d]: HADDR=0x%08h (expect PADDR=0x%08h, no stuck bits)",
                  i, test_addr[i], test_addr[i]), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("CONN006_SEQ", "TEST_CONNECTIVITY_006 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_006_seq
