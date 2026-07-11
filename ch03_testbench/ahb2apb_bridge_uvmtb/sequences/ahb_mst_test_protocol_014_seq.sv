// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_014_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_014
// DESCRIPTION: Stimulus for hresp_ok_on_successful_write_transfer.
//              Drives a single accepted source-side (AHB) NONSEQ write request so
//              the bridge completes a normal write transfer with no target error,
//              and the source-side HRESP must read 0 (OK) coincident with
//              HREADY_OUT=1 at completion. Flow produced by the bridge FSM and
//              the reactive APB slave (PSLVERR=0, no error injected):
//                T1 (FLOW-1, capture) : accepted request presented (HSEL=1,
//                                       HTRANS=NONSEQ, HWRITE=1, HADDR=0x0000_1000,
//                                       HSIZE=word, HWDATA=0xDEAD_BEEF, HREADY_IN=1);
//                                       address/control latched, HRESP=0
//                T2 (FLOW-2, SETUP)   : PSEL=1, PENABLE=0, PWRITE=1,
//                                       PADDR=0x0000_1000, PWDATA=0xDEAD_BEEF;
//                                       HRESP held at 0
//                T3 (FLOW-3, ACTIVE)  : PSEL=1, PENABLE=1; slave drives PREADY=1,
//                                       PSLVERR=0 (no error)
//                T4 (FLOW-5, complete): HREADY_OUT=1, HRESP=0 (OK); completion
//                                       gated by target ready
//              A STATUS read at 0xF04 then confirms STATUS=0x0000_0001 (READY=1,
//              no sticky TIMEOUT_ERR/PSLVERR/ADDR_ERR bits), proving the write
//              completed successfully with no error recorded.
//
//              Transfers:
//                1. WRITE — HTRANS=NONSEQ, HWRITE=1, HSIZE=word, HADDR=0x0000_1000,
//                           HWDATA=0xDEAD_BEEF
//                2. READ  — HTRANS=NONSEQ, HWRITE=0, HSIZE=word, HADDR=0x0000_0F04
//                           (STATUS register read-back)
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_014 steps 1-5 — confirm HRESP=0 throughout and at
//     completion (T4), HREADY_OUT=1 only after PREADY=1, no sticky STATUS error
//     bits, and PENABLE=1 exactly one cycle after PSEL=1/PENABLE=0.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. The PSEL/PENABLE/PREADY
//       phase timing, HRESP=0 source-side response, HREADY_OUT completion gating,
//       and PSLVERR=0 no-error behavior are produced by the bridge FSM and the
//       reactive APB slave and observed by the monitors; this sequence only
//       presents the accepted AHB request. Register access goes through the AHB
//       master as a raw transaction to PADDR 0xF04.
//
// CONFIDENCE: HIGH — single NONSEQ write plus a STATUS read-back.
// =============================================================================

class ahb_mst_test_protocol_014_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_014_seq)

  // Fixed stimulus from the XTP steps.
  localparam logic [31:0] TEST_ADDR   = 32'h0000_1000;  // write transfer address
  localparam logic [31:0] TEST_WDATA  = 32'hDEAD_BEEF;  // write data
  localparam logic [31:0] STATUS_ADDR = 32'h0000_0F04;  // STATUS register (sticky errs)

  function new(string name = "ahb_mst_test_protocol_014_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("PROTO014_SEQ",
      "Starting TEST_PROTOCOL_014: present one accepted AHB write request (HSEL=1, HTRANS=NONSEQ, HWRITE=1, HADDR=0x0000_1000, HWDATA=0xDEAD_BEEF); bridge completes a normal write with no target error (PSLVERR=0); source-side HRESP must be 0 (OK) coincident with HREADY_OUT=1; a STATUS read at 0xF04 then confirms STATUS=0x0000_0001 (READY=1, no sticky error)",
      UVM_MEDIUM)

    // ── Transfer 1 — accepted NONSEQ WRITE request (HRESP=0 on success) ───────
    // Presenting this accepted request drives the FSM through the source capture
    // phase (address/control latched, HRESP=0), target SETUP (PSEL=1, PENABLE=0,
    // PWRITE=1, PADDR=0x0000_1000, PWDATA=0xDEAD_BEEF), then target ACTIVE
    // (PSEL=1, PENABLE=1). The reactive APB slave drives PREADY=1, PSLVERR=0 to
    // complete the transfer with no error, so source-side completion shows
    // HREADY_OUT=1 with HRESP=0 (OK).
    req = ahb_mst_seq_item::type_id::create("ahb_proto_014_write");
    start_item(req);
    req.addr       = TEST_ADDR;
    req.write      = 1'b1;          // HWRITE=1 — write request
    req.wdata      = TEST_WDATA;    // HWDATA=0xDEAD_BEEF
    req.trans_type = 2'b10;         // NONSEQ/New transfer (accepted request)
    req.burst      = 3'b000;        // SINGLE
    req.size       = 3'b010;        // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO014_SEQ",
      $sformatf("WRITE REQUEST: HADDR=0x%08h HWDATA=0x%08h (FLOW-1 capture HRESP=0; FLOW-2 SETUP PSEL=1/PENABLE=0; FLOW-3 ACTIVE PSEL=1/PENABLE=1, PREADY=1/PSLVERR=0; FLOW-5 complete HREADY_OUT=1, HRESP=0 OK)",
                TEST_ADDR, TEST_WDATA), UVM_HIGH)
    finish_item(req);

    // ── Transfer 2 — STATUS register read-back (0xF04) ───────────────────────
    // After a successful write the STATUS register must show READY bit[0]=1 with
    // no sticky error bits (TIMEOUT_ERR, PSLVERR, ADDR_ERR all 0), i.e.
    // STATUS=0x0000_0001, confirming the write completed with no error recorded.
    req = ahb_mst_seq_item::type_id::create("ahb_proto_014_status_rd");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;          // HWRITE=0 — read request (STATUS read-back)
    req.wdata      = 32'h0;         // unused for reads
    req.trans_type = 2'b10;         // NONSEQ/New transfer
    req.burst      = 3'b000;        // SINGLE
    req.size       = 3'b010;        // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("PROTO014_SEQ",
      $sformatf("STATUS READ: HADDR=0x%08h (expect READY bit[0]=1, no sticky error -> STATUS=0x0000_0001)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);

    `uvm_info("PROTO014_SEQ", "TEST_PROTOCOL_014 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_014_seq
