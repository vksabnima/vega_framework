// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_004_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_004
// DESCRIPTION: Stimulus for in_order_sequence_data_integrity.
//              Drives a four-beat INCR4 word-write burst with distinct data
//              patterns, then reads the same four addresses back in order to
//              confirm multi-transfer data integrity and in-order handling.
//                WRITE phase (NONSEQ then SEQ, HSIZE=word, stride 0x4):
//                  T1: HADDR=0x0000_4000 HTRANS=NONSEQ HWDATA=0xFFFF_FFFF (all 1s)
//                  T2: HADDR=0x0000_4004 HTRANS=SEQ    HWDATA=0x0000_0000 (all 0s)
//                  T3: HADDR=0x0000_4008 HTRANS=SEQ    HWDATA=0xAAAA_AAAA (alt)
//                  T4: HADDR=0x0000_400C HTRANS=SEQ    HWDATA=0x5555_5555 (alt)
//                READ phase (NONSEQ then SEQ, same addresses, HWRITE=0):
//                  read 0x4000, 0x4004, 0x4008, 0x400C — expect the written
//                  patterns returned in order on HRDATA.
//              The bridge must re-drive each beat onto PADDR/PWDATA in order and
//              return the stored data unchanged with HRESP=0.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_004 steps 1-5 — distinct-pattern INCR4 word burst
//     write then in-order read-back, target PADDR sequence
//     [0x4000, 0x4004, 0x4008, 0x400C], stride 0x4 matching HSIZE=3'b010.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed INCR4 word write+read burst, in-order datapath stimulus.
// =============================================================================

class ahb_mst_test_main_datapath_004_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_004_seq)

  // INCR4 burst base address — word-aligned, advances by 0x4 per beat.
  localparam logic [31:0] DP_BASE = 32'h0000_4000;
  localparam int unsigned N_BEATS = 4;

  function new(string name = "ahb_mst_test_main_datapath_004_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    int unsigned i;
    logic [31:0] beat_addr;
    logic [31:0] beat_data;
    // Distinct per-beat HWDATA patterns: all 1s, all 0s, alternating, alternating.
    logic [31:0] beat_data_tbl [N_BEATS] = '{
      32'hFFFF_FFFF, 32'h0000_0000, 32'hAAAA_AAAA, 32'h5555_5555
    };

    `uvm_info("DP004_SEQ",
      "Starting TEST_MAIN_DATAPATH_004: INCR4 word-write burst then in-order read-back",
      UVM_MEDIUM)

    // ── PHASE 1 — four word WRITE beats (NONSEQ then SEQ) ────────────────────
    // Beat 0 is NONSEQ (new transfer); beats 1..3 are SEQ continuations of the
    // INCR4 burst. Each beat's address advances by 0x4 (HSIZE=word). The bridge
    // must re-drive HADDR/HWDATA onto PADDR/PWDATA in order, producing PADDR
    // [0x4000, 0x4004, 0x4008, 0x400C] with the distinct data patterns intact.
    for (i = 0; i < N_BEATS; i++) begin
      beat_addr = DP_BASE + (i << 2);                 // 0x4000, 0x4004, 0x4008, 0x400C
      beat_data = beat_data_tbl[i];

      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp004_wr_%0d", i));
      start_item(req);
      req.addr       = beat_addr;                     // HADDR advances by 0x4 per beat
      req.write      = 1'b1;                           // HWRITE=1 (write)
      req.wdata      = beat_data;                      // HWDATA per beat (distinct pattern)
      req.trans_type = (i == 0) ? 2'b10 : 2'b11;       // beat0 NONSEQ, rest SEQ
      req.burst      = 3'b011;                          // HBURST=INCR4
      req.size       = 3'b010;                          // HSIZE=word (32-bit)
      `uvm_info("DP004_SEQ",
        $sformatf("WR BEAT[%0d] %s: HADDR=0x%08h HWDATA=0x%08h (expect PADDR=0x%08h)",
                  i, (i == 0) ? "NONSEQ" : "SEQ", beat_addr, beat_data, beat_addr), UVM_HIGH)
      finish_item(req);
    end

    // ── PHASE 2 — read the same four addresses back in order ─────────────────
    // The APB slave memory model returns the value stored by the matching write,
    // so each read should return the distinct pattern written above, in address
    // order (0x4000 -> 0x400C). Read only issued after the write beats complete.
    for (i = 0; i < N_BEATS; i++) begin
      beat_addr = DP_BASE + (i << 2);                 // 0x4000, 0x4004, 0x4008, 0x400C
      beat_data = beat_data_tbl[i];                   // expected read-back value

      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp004_rd_%0d", i));
      start_item(req);
      req.addr       = beat_addr;                     // HADDR advances by 0x4 per beat
      req.write      = 1'b0;                           // HWRITE=0 (read)
      req.wdata      = 32'h0;                          // unused for reads
      req.trans_type = (i == 0) ? 2'b10 : 2'b11;       // beat0 NONSEQ, rest SEQ
      req.burst      = 3'b011;                          // HBURST=INCR4
      req.size       = 3'b010;                          // HSIZE=word (32-bit)
      `uvm_info("DP004_SEQ",
        $sformatf("RD BEAT[%0d] %s: HADDR=0x%08h expect HRDATA=0x%08h",
                  i, (i == 0) ? "NONSEQ" : "SEQ", beat_addr, beat_data), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("DP004_SEQ", "TEST_MAIN_DATAPATH_004 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_004_seq
