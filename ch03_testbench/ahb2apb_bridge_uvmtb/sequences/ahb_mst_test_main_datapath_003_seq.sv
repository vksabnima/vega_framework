// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_003_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_003
// DESCRIPTION: Stimulus for sequential_burst_increment_halfword_size.
//              Drives an incrementing multi-transfer sequence (NONSEQ then SEQ)
//              with HSIZE=halfword so target addresses advance by 0x2 per beat
//              (distinct from the word/0x4 case) and are handled in-order.
//              INCR4 burst, four halfword writes:
//                T1: HADDR=0x0000_3000 HTRANS=NONSEQ HWDATA=0x0000_AAAA (beat0)
//                T2: HADDR=0x0000_3002 HTRANS=SEQ    HWDATA=0x0000_5555 (beat1)
//                T3: HADDR=0x0000_3004 HTRANS=SEQ    HWDATA=0x0000_FFFF (beat2)
//                T4: HADDR=0x0000_3006 HTRANS=SEQ    HWDATA=0x0000_CCCC (beat3)
//              The bridge must re-drive each beat onto PADDR/PWDATA in order,
//              with PADDR advancing by 0x2 (HSIZE=halfword) per beat and HRESP=0.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_003 steps 1-5 — incrementing NONSEQ/SEQ halfword
//     burst, target PADDR sequence [0x3000, 0x3002, 0x3004, 0x3006] in-order,
//     stride 0x2 matching HSIZE=3'b001.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed INCR4 halfword-write burst, in-order datapath stimulus.
// =============================================================================

class ahb_mst_test_main_datapath_003_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_003_seq)

  // INCR4 burst base address — halfword-aligned, advances by 0x2 per beat.
  localparam logic [31:0] DP_BASE = 32'h0000_3000;
  localparam int unsigned N_BEATS = 4;

  function new(string name = "ahb_mst_test_main_datapath_003_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    int unsigned i;
    logic [31:0] beat_addr;
    logic [31:0] beat_data;
    // Per-beat HWDATA: 0xAAAA, 0x5555, 0xFFFF, 0xCCCC (16-bit halfword payloads).
    logic [31:0] beat_data_tbl [N_BEATS] = '{
      32'h0000_AAAA, 32'h0000_5555, 32'h0000_FFFF, 32'h0000_CCCC
    };

    `uvm_info("DP003_SEQ",
      "Starting TEST_MAIN_DATAPATH_003: INCR4 halfword-write burst (NONSEQ then SEQ)",
      UVM_MEDIUM)

    // Four halfword WRITE beats. Beat 0 is NONSEQ (new transfer); beats 1..3 are
    // SEQ continuations of the INCR4 burst. Each beat's address advances by 0x2
    // (HSIZE=halfword). The bridge must re-drive HADDR/HWDATA onto PADDR/PWDATA in
    // order, producing PADDR [0x3000, 0x3002, 0x3004, 0x3006] — stride 0x2,
    // distinct from the word (0x4) case.
    for (i = 0; i < N_BEATS; i++) begin
      beat_addr = DP_BASE + (i << 1);                 // 0x3000, 0x3002, 0x3004, 0x3006
      beat_data = beat_data_tbl[i];

      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp003_wr_%0d", i));
      start_item(req);
      req.addr       = beat_addr;                     // HADDR advances by 0x2 per beat
      req.write      = 1'b1;                           // HWRITE=1 (write)
      req.wdata      = beat_data;                      // HWDATA per beat
      req.trans_type = (i == 0) ? 2'b10 : 2'b11;       // beat0 NONSEQ, rest SEQ
      req.burst      = 3'b011;                          // HBURST=INCR4
      req.size       = 3'b001;                          // HSIZE=halfword (16-bit)
      `uvm_info("DP003_SEQ",
        $sformatf("BEAT[%0d] %s: HADDR=0x%08h HWDATA=0x%08h (expect PADDR=0x%08h advance +0x2)",
                  i, (i == 0) ? "NONSEQ" : "SEQ", beat_addr, beat_data, beat_addr), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("DP003_SEQ", "TEST_MAIN_DATAPATH_003 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_003_seq
