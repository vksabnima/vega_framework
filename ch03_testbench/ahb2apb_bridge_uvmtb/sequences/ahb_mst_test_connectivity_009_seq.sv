// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_009_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_009
// DESCRIPTION: Stimulus for pclk_clock_connectivity.
//              Verifies peripheral-side phase progression (SETUP->ACTIVE) advances
//              only on PCLK rising edges. A source-side write transfer is driven on
//              AHB to HADDR=0x0000_3000 (HWRITE=1, HSEL=1, HTRANS=2'b10 NONSEQ,
//              HWDATA=0x1234_5678). The bridge maps this to a peripheral write that
//              steps through:
//                SETUP  — PSEL=1, PENABLE=0, PADDR=0x0000_3000 (synchronous to PCLK)
//                ACTIVE — PSEL=1, PENABLE=1 (asserts exactly one PCLK cycle later)
//              A second back-to-back write to the same address keeps a request
//              pending so the PCLK-gated phase advance can be observed. The
//              monitors/scoreboard verify that PENABLE asserts exactly one PCLK
//              cycle after PSEL, PADDR=0x0000_3000 stays stable across the transfer,
//              and all peripheral-side transitions align to PCLK rising edges. This
//              sequence supplies the source-side write stimulus.
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_009 steps 1-6 — issue a source write (HWRITE=1,
//     HSEL=1, HTRANS=2'b10) to HADDR=0x0000_3000 with HWDATA=0x1234_5678 and
//     confirm the peripheral SETUP->ACTIVE progression occurs only on PCLK
//     rising edges, PENABLE one cycle after PSEL, PADDR stable
//     (peripheral_side_interface_signals, pages page 8).
//
// NOTE: No .randomize() — fixed address/data per [TC1]. PCLK edge alignment,
//       SETUP/ACTIVE phase timing, and signal-stability observation are done by
//       the monitors, not this sequence. The peripheral-side phase progression
//       is produced by the DUT bridge FSM clocked by PCLK.
//
// CONFIDENCE: HIGH — straightforward PCLK clock connectivity write stimulus.
// =============================================================================

class ahb_mst_test_connectivity_009_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_009_seq)

  function new(string name = "ahb_mst_test_connectivity_009_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    int unsigned i;

    `uvm_info("CONN009_SEQ",
      "Starting TEST_CONNECTIVITY_009: PCLK clock connectivity (SETUP->ACTIVE PCLK-gated)",
      UVM_MEDIUM)

    // ── Steps 1-5 — drive write transfers to HADDR=0x0000_3000 ───────────────
    // The first write exercises the SETUP->ACTIVE phase progression; the bridge
    // raises PSEL (SETUP) then PENABLE exactly one PCLK cycle later (ACTIVE),
    // with PADDR held at 0x0000_3000. A second back-to-back write to the same
    // address keeps a peripheral request pending so the PCLK-gated phase advance
    // is observable. PCLK edge alignment is checked by the monitors/scoreboard.
    for (i = 0; i < 2; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_conn009_wr_%0d", i));
      start_item(req);
      req.addr       = 32'h0000_3000;  // fixed source address per XTP steps
      req.write      = 1'b1;           // Write — drive HSEL=1, HTRANS=2'b10
      req.wdata      = 32'h1234_5678;  // fixed write payload per XTP steps
      req.trans_type = 2'b10;          // NONSEQ — new transfer
      req.burst      = 3'b000;         // SINGLE
      req.size       = 3'b010;         // Word (32-bit)
      req.post_randomize();
      `uvm_info("CONN009_SEQ",
        $sformatf("WRITE[%0d]: HADDR=0x0000_3000 HWDATA=0x1234_5678 (expect SETUP PSEL=1/PENABLE=0 then ACTIVE PENABLE=1 one PCLK later, PADDR stable)",
                  i), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("CONN009_SEQ", "TEST_CONNECTIVITY_009 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_009_seq
