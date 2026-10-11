// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_016_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_016
// DESCRIPTION: Stimulus for read_data_patterns_integrity. Drives three accepted
//              AHB word READs to distinct word-aligned addresses and checks that
//              the read-data return path preserves data integrity for all-1s,
//              all-0s, and alternating bit patterns flowing from PRDATA to HRDATA:
//                READ 1 : HADDR=0x0000_3000 — target returns PRDATA=0xFFFF_FFFF
//                READ 2 : HADDR=0x0000_3004 — target returns PRDATA=0x0000_0000
//                READ 3 : HADDR=0x0000_3008 — target returns PRDATA=0xAAAA_5555
//              For each read the bridge takes the APB target from setup
//              (PSEL=1, PENABLE=0, PWRITE=0) into the active phase
//              (PSEL=1, PENABLE=1, PREADY=1) and returns the captured PRDATA on
//              HRDATA at completion (HREADY_OUT=1, HRESP=0). The returned HRDATA
//              must equal the driven PRDATA bit-for-bit for every pattern.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_016 steps 1-6 — three accepted reads whose APB
//     active-phase PRDATA values (all-1s, all-0s, alternating) must appear
//     unchanged on HRDATA, with HRESP=0 for all three.
//
// NOTE: No .randomize() — fixed addresses per [TC1]. The PRDATA pattern values
//       are produced/returned by the passive APB slave agent, not driven from
//       this sequence; the sequence only issues the read transfers on AHB.
//
// CONFIDENCE: HIGH — three fixed-address single word reads; PRDATA->HRDATA data
//             integrity is a property of the bridge read return path observed by
//             the monitors and checked by the scoreboard (VG3).
// =============================================================================

class ahb_mst_test_main_datapath_016_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_016_seq)

  // Fixed, distinct word-aligned read addresses (one per pattern).
  localparam logic [31:0] DP016_ADDR0 = 32'h0000_3000;  // all-1s   pattern
  localparam logic [31:0] DP016_ADDR1 = 32'h0000_3004;  // all-0s   pattern
  localparam logic [31:0] DP016_ADDR2 = 32'h0000_3008;  // alternating pattern

  function new(string name = "ahb_mst_test_main_datapath_016_seq");
    super.new(name);
  endfunction : new

  // Issue one accepted SINGLE word NONSEQ read to the given address.
  task do_read(input logic [31:0] addr, input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp016_%s", tag));
    start_item(req);
    req.addr       = addr;    // HADDR
    req.write      = 1'b0;    // HWRITE=0 (read)
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;  // HBURST=SINGLE
    req.size       = 3'b010;  // HSIZE=word (32-bit)
    req.post_randomize();
    `uvm_info("DP016_SEQ",
      $sformatf("READ %s: HADDR=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("DP016_SEQ",
      "Starting TEST_MAIN_DATAPATH_016: three reads checking PRDATA->HRDATA integrity (all-1s, all-0s, alternating)",
      UVM_MEDIUM)

    // ── READ 1 — all-1s pattern (PRDATA=0xFFFF_FFFF) ─────────────────────────
    do_read(DP016_ADDR0, "rd0_all1s");

    // ── READ 2 — all-0s pattern (PRDATA=0x0000_0000) ─────────────────────────
    do_read(DP016_ADDR1, "rd1_all0s");

    // ── READ 3 — alternating pattern (PRDATA=0xAAAA_5555) ────────────────────
    do_read(DP016_ADDR2, "rd2_alt");

    `uvm_info("DP016_SEQ", "TEST_MAIN_DATAPATH_016 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_016_seq
