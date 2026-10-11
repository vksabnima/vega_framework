// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_006_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_006
// DESCRIPTION: Stimulus for basic_read_translation_and_verify.
//              Verifies a source-side read translates to a target-side read
//              access and that HRDATA reflects PRDATA only after target-side
//              completion. The APB slave is a memory model, so the target read
//              data (PRDATA=0xCAFE_F00D) is made deterministic by first priming
//              the location with a write of the same value, then issuing the
//              read under test:
//                PRIME: HADDR=0x0000_2000 HWRITE=1 HWDATA=0xCAFE_F00D
//                READ : HADDR=0x0000_2000 HWRITE=0 — expect HRDATA=0xCAFE_F00D
//              The bridge must capture the source-side read (FLOW-1), drive the
//              target setup phase PSEL=1/PENABLE=0/PWRITE=0 (FLOW-2), the active
//              phase PSEL=1/PENABLE=1 with PREADY=1 returning PRDATA (FLOW-3),
//              and complete with HRESP=0/HREADY_OUT=1 presenting HRDATA only
//              after the active-phase completion (FLOW-5). PADDR==HADDR and
//              HRDATA==PRDATA confirm the 1:1 read mapping.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_006 steps 1-5 — single source-side read
//     HADDR=0x0000_2000 translated to a target read with PADDR=0x0000_2000,
//     PWRITE=0; HRDATA=0xCAFE_F00D equals PRDATA and is valid only after the
//     target-side PREADY=1 active-phase completion.
//
// NOTE: No .randomize() — fixed address/data per [TC1].
//
// CONFIDENCE: HIGH — single fixed word read (memory-model primed), basic datapath.
// =============================================================================

class ahb_mst_test_main_datapath_006_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_006_seq)

  // Single-transfer read target — word-aligned address and expected payload.
  localparam logic [31:0] DP_ADDR = 32'h0000_2000;
  localparam logic [31:0] DP_DATA = 32'hCAFE_F00D;

  function new(string name = "ahb_mst_test_main_datapath_006_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP006_SEQ",
      "Starting TEST_MAIN_DATAPATH_006: prime then single word read translation",
      UVM_MEDIUM)

    // ── PHASE 1 — PRIME the target location (memory-model write) ──────────────
    // The APB slave is a memory model; prime HADDR=0x0000_2000 with 0xCAFE_F00D
    // so the read under test returns PRDATA=0xCAFE_F00D deterministically.
    req = ahb_mst_seq_item::type_id::create("ahb_dp006_prime");
    start_item(req);
    req.addr       = DP_ADDR;     // HADDR=0x0000_2000
    req.write      = 1'b1;        // HWRITE=1 (write to prime memory)
    req.wdata      = DP_DATA;     // HWDATA=0xCAFE_F00D
    req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word (32-bit)
    `uvm_info("DP006_SEQ",
      $sformatf("PRIME WRITE: HADDR=0x%08h HWDATA=0x%08h", DP_ADDR, DP_DATA), UVM_HIGH)
    finish_item(req);

    // ── PHASE 2 — source-side READ under test (FLOW-1 capture) ────────────────
    // Drive HADDR=0x0000_2000, HWRITE=0 as a SINGLE word NONSEQ transfer. The
    // bridge must translate this 1:1 onto the target side producing a read
    // (PWRITE=0, PADDR=0x0000_2000) and return HRDATA=PRDATA=0xCAFE_F00D only
    // after the target-side PREADY=1 active-phase completion (HRESP=0).
    req = ahb_mst_seq_item::type_id::create("ahb_dp006_rd");
    start_item(req);
    req.addr       = DP_ADDR;     // HADDR=0x0000_2000
    req.write      = 1'b0;        // HWRITE=0 (read)
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word (32-bit)
    `uvm_info("DP006_SEQ",
      $sformatf("READ: HADDR=0x%08h expect HRDATA=PRDATA=0x%08h (PWRITE=0)",
                DP_ADDR, DP_DATA), UVM_HIGH)
    finish_item(req);

    `uvm_info("DP006_SEQ", "TEST_MAIN_DATAPATH_006 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_006_seq
