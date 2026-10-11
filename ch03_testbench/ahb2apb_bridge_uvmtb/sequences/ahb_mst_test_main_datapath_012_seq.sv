// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_012_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_012
// DESCRIPTION: Stimulus for back_to_back_writes_with_stall_data_patterns. Drives
//              three consecutive accepted AHB word WRITES carrying the classic
//              data-integrity patterns (all 1s, all 0s, alternating) to three
//              distinct word-aligned addresses, then reads the same three
//              addresses back. Each write's target-side APB ACTIVE phase is held
//              by PREADY=0 wait states supplied by the reactive APB slave
//              sequence; the bridge must hold PWDATA stable and HREADY_OUT=0 for
//              the duration of each stall and complete (HREADY_OUT=1) only when
//              PREADY rises:
//                WRITE #1 : HADDR=0x0000_3000, HWDATA=0xFFFF_FFFF (all 1s)
//                WRITE #2 : HADDR=0x0000_3004, HWDATA=0x0000_0000 (all 0s)
//                WRITE #3 : HADDR=0x0000_3008, HWDATA=0xAAAA_5555 (alternating)
//              Read-back of 0x3000/0x3004/0x3008 must return the same three
//              patterns, proving data integrity survives the PREADY back-pressure.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_012 steps 1-6 — three back-to-back writes whose APB
//     active phases are each held by PREADY=0 stalls; PWDATA held stable per
//     transfer, HREADY_OUT low during stall / high at completion, then read-back
//     compares each address to its written pattern.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. The PREADY wait states
//       are produced by the passive APB slave agent, not driven from this
//       sequence.
//
// CONFIDENCE: HIGH — three fixed writes + three read-backs; PWDATA stability under
//             back-pressure is a property of the bridge target FSM observed by the
//             monitors.
// =============================================================================

class ahb_mst_test_main_datapath_012_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_012_seq)

  // Fixed target addresses (word-aligned) and their data-integrity patterns.
  localparam logic [31:0] DP012_ADDR0 = 32'h0000_3000;
  localparam logic [31:0] DP012_ADDR1 = 32'h0000_3004;
  localparam logic [31:0] DP012_ADDR2 = 32'h0000_3008;
  localparam logic [31:0] DP012_DATA0 = 32'hFFFF_FFFF;  // all 1s
  localparam logic [31:0] DP012_DATA1 = 32'h0000_0000;  // all 0s
  localparam logic [31:0] DP012_DATA2 = 32'hAAAA_5555;  // alternating

  function new(string name = "ahb_mst_test_main_datapath_012_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    logic [31:0] wr_addr [3];
    logic [31:0] wr_data [3];
    int unsigned i;

    wr_addr[0] = DP012_ADDR0; wr_data[0] = DP012_DATA0;
    wr_addr[1] = DP012_ADDR1; wr_data[1] = DP012_DATA1;
    wr_addr[2] = DP012_ADDR2; wr_data[2] = DP012_DATA2;

    `uvm_info("DP012_SEQ",
      "Starting TEST_MAIN_DATAPATH_012: three back-to-back writes (all 1s, all 0s, alternating) under PREADY back-pressure, then read-back",
      UVM_MEDIUM)

    // ── PHASE 1 — three back-to-back accepted SINGLE word NONSEQ writes ───────
    // The bridge takes each APB target from setup (PSEL=1, PENABLE=0) into the
    // active phase (PSEL=1, PENABLE=1). While the APB slave holds PREADY=0 the
    // active phase is held: PWDATA=HWDATA stays stable, HREADY_OUT stays 0, and
    // the transfer completes (HREADY_OUT=1) only once PREADY rises.
    for (i = 0; i < 3; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp012_wr_%0d", i));
      start_item(req);
      req.addr       = wr_addr[i];  // HADDR=0x3000 / 0x3004 / 0x3008
      req.write      = 1'b1;        // HWRITE=1 (write)
      req.wdata      = wr_data[i];  // HWDATA pattern under test
      req.trans_type = 2'b10;       // HTRANS=NONSEQ (new transfer)
      req.burst      = 3'b000;      // HBURST=SINGLE
      req.size       = 3'b010;      // HSIZE=word (32-bit)
      `uvm_info("DP012_SEQ",
        $sformatf("WRITE[%0d]: HADDR=0x%08h HWDATA=0x%08h", i, wr_addr[i], wr_data[i]),
        UVM_HIGH)
      finish_item(req);
    end

    // ── PHASE 2 — read-back of the same three addresses ──────────────────────
    // Each read should return the pattern stored by the matching write, proving
    // the data survived the PREADY back-pressure on the write side.
    for (i = 0; i < 3; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp012_rd_%0d", i));
      start_item(req);
      req.addr       = wr_addr[i];  // same address as the write
      req.write      = 1'b0;        // HWRITE=0 (read)
      req.wdata      = 32'h0;       // unused for reads
      req.trans_type = 2'b10;       // HTRANS=NONSEQ
      req.burst      = 3'b000;      // HBURST=SINGLE
      req.size       = 3'b010;      // HSIZE=word (32-bit)
      `uvm_info("DP012_SEQ",
        $sformatf("READ[%0d]: HADDR=0x%08h expect HRDATA=0x%08h", i, wr_addr[i], wr_data[i]),
        UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("DP012_SEQ", "TEST_MAIN_DATAPATH_012 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_012_seq
