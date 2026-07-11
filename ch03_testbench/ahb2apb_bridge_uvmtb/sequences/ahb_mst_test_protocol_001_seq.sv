// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_001
// DESCRIPTION: Stimulus for source_capture_to_target_setup_progression.
//              Drives one accepted source-side (AHB) request so the bridge
//              captures it and translates it into a target-side (APB) SETUP ->
//              ACTIVE phase progression with correct PSEL/PENABLE timing.
//
//              Single word-aligned WRITE transfer:
//                HTRANS=2'b10 (NONSEQ/New), HWRITE=1, HSIZE=word,
//                HADDR=0x0000_0100, HWDATA=0x0000_DADA
//
//              The bridge is expected to produce:
//                SETUP  : PSEL=1, PENABLE=0, PADDR=0x0000_0100, PWRITE=1
//                ACTIVE : PSEL=1, PENABLE=1 (one cycle after PSEL asserts),
//                         PADDR/PWRITE/PWDATA stable from SETUP through ACTIVE.
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_001 steps 1-4 — drive a NONSEQ write and observe the
//     captured request progress through the APB SETUP and ACTIVE phases.
//
// NOTE: No .randomize() — fixed address/data per [TC1].
//
// CONFIDENCE: HIGH — single NONSEQ write exercising SETUP->ACTIVE timing.
// =============================================================================

class ahb_mst_test_protocol_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_001_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR = 32'h0000_0100;
  localparam logic [31:0] TEST_DATA = 32'h0000_DADA;

  function new(string name = "ahb_mst_test_protocol_001_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO001_SEQ",
      "Starting TEST_PROTOCOL_001: drive one NONSEQ write to exercise APB SETUP->ACTIVE",
      UVM_MEDIUM)

    // Single source-side WRITE request. The bridge captures HADDR/HWDATA and
    // drives the APB SETUP phase (PSEL=1, PENABLE=0) then the ACTIVE phase
    // (PSEL=1, PENABLE=1) one cycle later.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_wr");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b1;    // HWRITE=1 — write request
    req.wdata      = TEST_DATA;
    req.trans_type = 2'b10;   // NONSEQ/New transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO001_SEQ",
      $sformatf("WRITE: HADDR=0x%08h HWDATA=0x%08h (expect PADDR=0x%08h, SETUP->ACTIVE)",
                TEST_ADDR, TEST_DATA, TEST_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO001_SEQ", "TEST_PROTOCOL_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_001_seq
