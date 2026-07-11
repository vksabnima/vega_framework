// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_002_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_002
// DESCRIPTION: Stimulus for sequential_burst_address_increment_word.
//              Drives an incrementing multi-transfer sequence (NONSEQ then SEQ)
//              with HSIZE=word so target addresses advance by 0x4 per beat and
//              are handled in-order. INCR4 burst, four word writes:
//                T1: HADDR=0x0000_2000 HTRANS=NONSEQ HWDATA=0x1111_1111 (beat0)
//                T2: HADDR=0x0000_2004 HTRANS=SEQ    HWDATA=0x2222_2222 (beat1)
//                T3: HADDR=0x0000_2008 HTRANS=SEQ    HWDATA=0x3333_3333 (beat2)
//                T4: HADDR=0x0000_200C HTRANS=SEQ    HWDATA=0x4444_4444 (beat3)
//              The bridge must re-drive each beat onto PADDR/PWDATA in order,
//              with PADDR advancing by 0x4 (HSIZE=word) per beat and HRESP=0.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_002 steps 1-5 — incrementing NONSEQ/SEQ word burst,
//     target PADDR sequence [0x2000, 0x2004, 0x2008, 0x200C] in-order.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed INCR4 word-write burst, in-order datapath stimulus.
// =============================================================================

class ahb_mst_test_main_datapath_002_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_002_seq)

  // INCR4 burst base address — word-aligned, advances by 0x4 per beat.
  localparam logic [31:0] DP_BASE = 32'h0000_2000;
  localparam int unsigned N_BEATS = 4;

  function new(string name = "ahb_mst_test_main_datapath_002_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    int unsigned i;
    logic [31:0] beat_addr;
    logic [31:0] beat_data;

    `uvm_info("DP002_SEQ",
      "Starting TEST_MAIN_DATAPATH_002: INCR4 word-write burst (NONSEQ then SEQ)",
      UVM_MEDIUM)

    // Four word WRITE beats. Beat 0 is NONSEQ (new transfer); beats 1..3 are SEQ
    // continuations of the INCR4 burst. Each beat's address advances by 0x4
    // (HSIZE=word). The bridge must re-drive HADDR/HWDATA onto PADDR/PWDATA in
    // order, producing PADDR [0x2000, 0x2004, 0x2008, 0x200C].
    for (i = 0; i < N_BEATS; i++) begin
      beat_addr = DP_BASE + (i << 2);                 // 0x2000, 0x2004, 0x2008, 0x200C
      // Per-beat data: 0x1111_1111, 0x2222_2222, 0x3333_3333, 0x4444_4444
      beat_data = 32'h1111_1111 * (i + 1);

      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp002_wr_%0d", i));
      start_item(req);
      req.addr       = beat_addr;                     // HADDR advances by 0x4 per beat
      req.write      = 1'b1;                           // HWRITE=1 (write)
      req.wdata      = beat_data;                      // HWDATA per beat
      req.trans_type = (i == 0) ? 2'b10 : 2'b11;       // beat0 NONSEQ, rest SEQ
      req.burst      = 3'b011;                          // HBURST=INCR4
      req.size       = 3'b010;                          // HSIZE=word (32-bit)
      `uvm_info("DP002_SEQ",
        $sformatf("BEAT[%0d] %s: HADDR=0x%08h HWDATA=0x%08h (expect PADDR=0x%08h advance +0x4)",
                  i, (i == 0) ? "NONSEQ" : "SEQ", beat_addr, beat_data, beat_addr), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("DP002_SEQ", "TEST_MAIN_DATAPATH_002 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_002_seq
