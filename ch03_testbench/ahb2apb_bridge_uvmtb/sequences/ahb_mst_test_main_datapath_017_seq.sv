// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_017_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_017
// DESCRIPTION: Stimulus for read_data_address_range_correlation. Drives three
//              accepted AHB word READs spanning the 32-bit address range (low,
//              mid, high) and checks that the read data returned on HRDATA
//              correlates with the correct target address with no cross
//              contamination:
//                READ 1 : HADDR=0x0000_0000 (low)  — target returns PRDATA=0x1111_1111
//                READ 2 : HADDR=0x8000_0000 (mid)  — target returns PRDATA=0x2222_2222
//                READ 3 : HADDR=0xFFFF_FFFC (high) — target returns PRDATA=0x3333_3333
//              For each read the bridge mirrors HADDR onto PADDR, takes the APB
//              target from setup (PSEL=1, PENABLE=0, PWRITE=0) into the active
//              phase (PSEL=1, PENABLE=1, PREADY=1) and returns the captured
//              PRDATA on HRDATA at completion (HREADY_OUT=1, HRESP=0). The HRDATA
//              returned for each address must equal the PRDATA driven at that
//              address's target access.
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_017 steps 1-6 — three accepted reads across the
//     low/mid/high address range whose per-address PRDATA must appear on HRDATA
//     with PADDR mirroring HADDR and HRESP=0 for all three.
//
// NOTE: No .randomize() — fixed addresses per [TC1]. The PRDATA values are
//       produced/returned by the passive APB slave agent, not driven from this
//       sequence; the sequence only issues the read transfers on AHB.
//
// CONFIDENCE: HIGH — three fixed-address single word reads; PADDR<-HADDR and
//             PRDATA->HRDATA address-correlated mapping is a property of the
//             bridge read return path observed by the monitors and checked by
//             the scoreboard (VG1/VG3).
// =============================================================================

class ahb_mst_test_main_datapath_017_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_017_seq)

  // Fixed read addresses spanning the 32-bit range (low / mid / high).
  localparam logic [31:0] DP017_ADDR_LOW  = 32'h0000_0000;  // low  address
  localparam logic [31:0] DP017_ADDR_MID  = 32'h8000_0000;  // mid  address
  localparam logic [31:0] DP017_ADDR_HIGH = 32'hFFFF_FFFC;  // high address (word-aligned)

  function new(string name = "ahb_mst_test_main_datapath_017_seq");
    super.new(name);
  endfunction : new

  // Issue one accepted SINGLE word NONSEQ read to the given address.
  task do_read(input logic [31:0] addr, input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_dp017_%s", tag));
    start_item(req);
    req.addr       = addr;    // HADDR
    req.write      = 1'b0;    // HWRITE=0 (read)
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // HTRANS=NONSEQ (new transfer)
    req.burst      = 3'b000;  // HBURST=SINGLE
    req.size       = 3'b010;  // HSIZE=word (32-bit)
    req.post_randomize();
    `uvm_info("DP017_SEQ",
      $sformatf("READ %s: HADDR=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("DP017_SEQ",
      "Starting TEST_MAIN_DATAPATH_017: three reads checking HRDATA correlates with target address (low/mid/high)",
      UVM_MEDIUM)

    // ── READ 1 — low address (expect PRDATA=0x1111_1111) ─────────────────────
    do_read(DP017_ADDR_LOW, "rd0_low");

    // ── READ 2 — mid address (expect PRDATA=0x2222_2222) ─────────────────────
    do_read(DP017_ADDR_MID, "rd1_mid");

    // ── READ 3 — high address (expect PRDATA=0x3333_3333) ────────────────────
    do_read(DP017_ADDR_HIGH, "rd2_high");

    `uvm_info("DP017_SEQ", "TEST_MAIN_DATAPATH_017 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_017_seq
