// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_010_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_010
// DESCRIPTION: Stimulus for presetn_reset_connectivity.
//              Verifies PRESETn forces the peripheral-side outputs to their
//              defined reset values and that the interface recovers after
//              PRESETn deassertion. The peripheral reset behaviour (PSEL=0,
//              PENABLE=0, PADDR=0x0000_0000, PWDATA=0x0000_0000 while PRESETn=0)
//              is produced by the DUT bridge FSM and observed by the monitors —
//              PRESETn itself is driven by tb_top's reset generator, not by this
//              sequence.
//
//              This sequence supplies the source-side stimulus that exercises
//              the post-reset recovery path: after PRESETn deasserts and the
//              interface returns to idle, a fresh source write is issued to
//              HADDR=0x0000_4000 (HWRITE=1, HSEL=1, HTRANS=2'b10 NONSEQ,
//              HWDATA=0xCAFE_F00D). The bridge maps this to a peripheral write
//              that steps SETUP (PSEL=1, PENABLE=0) -> ACTIVE (PSEL=1,
//              PENABLE=1) with PADDR=0x0000_4000 and PWDATA=0xCAFE_F00D,
//              proving normal operation resumes and PRESETn connectivity holds.
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_010 steps 1-6 — during PRESETn=0 the peripheral
//     outputs hold reset values (PSEL=0, PENABLE=0, PADDR=0x0000_0000,
//     PWDATA=0x0000_0000, Table 8); after PRESETn deassertion a fresh write to
//     HADDR=0x0000_4000 / HWDATA=0xCAFE_F00D drives PADDR/PWDATA correctly
//     (peripheral_side_interface_signals, pages page 8).
//
// NOTE: No .randomize() — fixed address/data per [TC1]. Reset assertion and the
//       reset-value sampling are handled by tb_top's reset and the monitors;
//       this sequence drives the post-reset recovery write stimulus.
//
// CONFIDENCE: HIGH — straightforward post-reset recovery write stimulus.
// =============================================================================

class ahb_mst_test_connectivity_010_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_010_seq)

  function new(string name = "ahb_mst_test_connectivity_010_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("CONN010_SEQ",
      "Starting TEST_CONNECTIVITY_010: PRESETn reset connectivity (post-reset recovery write)",
      UVM_MEDIUM)

    // ── Steps 5-6 — fresh source write after PRESETn deassertion ─────────────
    // PRESETn assertion/deassertion and the reset-value sampling (PSEL=0,
    // PENABLE=0, PADDR=0x0000_0000, PWDATA=0x0000_0000) are driven by tb_top's
    // reset generator and observed by the monitors. Once the interface returns
    // to idle, this fresh write proves the peripheral path resumes normal
    // operation: SETUP PSEL=1/PENABLE=0 then ACTIVE PSEL=1/PENABLE=1 with
    // PADDR=0x0000_4000 and PWDATA=0xCAFE_F00D driven correctly post-reset.
    req = ahb_mst_seq_item::type_id::create("ahb_conn010_wr");
    start_item(req);
    req.addr       = 32'h0000_4000;  // fresh source address per XTP step 5
    req.write      = 1'b1;           // Write — drive HSEL=1, HTRANS=2'b10
    req.wdata      = 32'hCAFE_F00D;  // fixed write payload per XTP step 5
    req.trans_type = 2'b10;          // NONSEQ — new transfer
    req.burst      = 3'b000;         // SINGLE
    req.size       = 3'b010;         // Word (32-bit)
    req.post_randomize();
    `uvm_info("CONN010_SEQ",
      "WRITE: HADDR=0x0000_4000 HWDATA=0xCAFE_F00D (expect SETUP PSEL=1/PENABLE=0 then ACTIVE PENABLE=1, PADDR=0x0000_4000 post-reset)",
      UVM_HIGH)
    finish_item(req);

    `uvm_info("CONN010_SEQ", "TEST_CONNECTIVITY_010 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_010_seq
