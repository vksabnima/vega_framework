// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_018_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_018
// DESCRIPTION: Stimulus for read_data_not_returned_on_target_error. Drives a
//              single accepted AHB word READ to a target address whose APB-side
//              access returns PSLVERR=1 during the active phase. The bridge must
//              propagate the target error to the source as HRESP=1 (ERROR) and
//              flag the read completion as an error rather than delivering valid
//              read data:
//                T1 : HSEL=1, HTRANS=NONSEQ, HWRITE=0, HADDR=0x0000_4000
//                Setup  : PSEL=1, PENABLE=0, PWRITE=0, PADDR=0x0000_4000
//                Active : PSEL=1, PENABLE=1, PREADY=1, PSLVERR=1, PRDATA=0x0
//                Done   : HREADY_OUT=1, HRESP=1 (error) — read NOT delivered OKAY
//              After the errored read the sequence reads back the control/status
//              block: STATUS (0xF04) sticky PSLVERR bit and ERROR_ADDR (0xF08)
//              must reflect the failed access at 0x0000_4000.
//
// REGISTER MAP (raw AHB accesses to the register block):
//   CTRL       = 0xF00  (ENABLE bit0, SOFT_RST bit1, ...)
//   STATUS     = 0xF04  (READY b0, ADDR_ERR b4, PSLVERR b5, TIMEOUT b6, ERR_INT b7)
//   ERROR_ADDR = 0xF08  (captured error address)
//   ERROR_INFO = 0xF0C  (direction + coarse error class)
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_018 steps 1-6 — read at 0x0000_4000 with PSLVERR=1
//     on the target active phase produces HRESP=1 on the source side; STATUS
//     sticky PSLVERR=1 and ERROR_ADDR=0x0000_4000 captured; read completion is
//     flagged as error rather than a valid OKAY data return.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. The PSLVERR target
//       response is produced by the passive APB slave agent, not driven from
//       this sequence. No uvm_reg — register accesses are raw AHB transactions
//       to 0xF00..0xF0C.
//
// CONFIDENCE: MEDIUM — drives the documented error read flow; the HRESP/STATUS
//             checks live in the scoreboard / monitors.
// =============================================================================

class ahb_mst_test_main_datapath_018_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_018_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  // ── Control / status values ───────────────────────────────────────────────
  localparam logic [31:0] CTRL_ENABLE    = 32'h0000_0001;  // ENABLE=1
  localparam logic [31:0] STATUS_W1C      = 32'h0000_0001;  // clear sticky flags

  // ── Read target whose APB access returns PSLVERR=1 ────────────────────────
  localparam logic [31:0] DP018_ERR_ADDR = 32'h0000_4000;

  function new(string name = "ahb_mst_test_main_datapath_018_seq");
    super.new(name);
  endfunction : new

  // ── Helper: drive a single word WRITE transaction ─────────────────────────
  task automatic do_write(input logic [31:0] addr, input logic [31:0] data,
                          input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_wr_%s", tag));
    start_item(req);
    req.addr       = addr;
    req.write      = 1'b1;
    req.wdata      = data;
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("DP018_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // ── Helper: drive a single word READ transaction ──────────────────────────
  logic [31:0] last_rdata;
  logic        last_resp;
  task automatic do_read(input logic [31:0] addr, input string tag);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create($sformatf("ahb_rd_%s", tag));
    start_item(req);
    req.addr       = addr;
    req.write      = 1'b0;
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("DP018_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
    last_rdata = req.rdata;
    last_resp  = req.resp;
  endtask : do_read

  function void check_rdata(input logic [31:0] exp, input string what);
    if (last_rdata !== exp)
      `uvm_error("DP018_SEQ",
        $sformatf("%s mismatch: got 0x%08h, expected 0x%08h", what, last_rdata, exp))
    else
      `uvm_info("DP018_SEQ", $sformatf("%s OK: 0x%08h", what, last_rdata), UVM_LOW)
  endfunction

  task body();
    `uvm_info("DP018_SEQ",
      "Starting TEST_MAIN_DATAPATH_018: read with target PSLVERR=1 must return HRESP=1 (no valid data)",
      UVM_MEDIUM)

    // ── Preconditions: enable bridge, clear sticky STATUS flags ──────────────
    do_write(REG_CTRL,   CTRL_ENABLE, "ctrl_enable");
    do_write(REG_STATUS, STATUS_W1C,  "status_clear");
    do_read (REG_STATUS,              "status_init");

    // ── T1-T5: errored read at 0x0000_4000 ───────────────────────────────────
    // The APB slave returns PSLVERR=1 during the active phase. The bridge must
    // return HREADY_OUT=1 with HRESP=1 (ERROR) to the source; the read data is
    // NOT delivered as a valid OKAY result.
    do_read (DP018_ERR_ADDR, "err_read");
    if (last_resp !== 1'b1)
      `uvm_error("DP018_SEQ",
        $sformatf("Target (PSLVERR) read should return HRESP=1, got %0b", last_resp))
    else `uvm_info("DP018_SEQ", "PSLVERR read HRESP=1 OK", UVM_LOW)

    // ── T5-T6: observe sticky error log captured by the bridge ───────────────
    do_read (REG_STATUS,     "status_err");   // STATUS.PSLVERR sticky = 1
    // CTRL=0x01 (ERR_INT_EN=0): READY(b0)|PSLVERR(b5) => 0x21.
    check_rdata(32'h0000_0021, "STATUS sticky PSLVERR after errored read");
    do_read (REG_ERROR_ADDR, "erraddr_capt"); // ERROR_ADDR = 0x0000_4000
    check_rdata(DP018_ERR_ADDR, "ERROR_ADDR captured PSLVERR address");
    do_read (REG_ERROR_INFO, "errinfo_capt");

    `uvm_info("DP018_SEQ", "TEST_MAIN_DATAPATH_018 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_018_seq
