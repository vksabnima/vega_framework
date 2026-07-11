// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_006_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_006
// DESCRIPTION: Stimulus for ctrl_reg_rw_field_writeback.
//              Verifies that the R/W fields in CTRL accept programmed values
//              and read back correctly.
//
//              Preconditions: PCLK/HCLK running, PRESETn deasserted, CTRL at
//              reset value 0x0000_0001.
//
//              Drives, through the AHB master, a write/read pair to
//              REG_BASE+0x00 = 0x0000_0F00:
//                1. WRITE CTRL = 0x0000_00A9 — program R/W fields:
//                     bit0 ENABLE=1, bits6:4 TIMEOUT_VAL=3'b010, bit7 TIMEOUT_EN=1
//                     (0xA9 = 1010_1001).
//                2. READ CTRL — expect PRDATA = 0x0000_00A9, confirming the R/W
//                     fields latched the programmed value and read back unchanged.
//
//              Decoded CTRL fields written / expected on read-back:
//                bit0      ENABLE      = 1
//                bit1      SOFT_RST    = 0   (not written)
//                bit2      reserved    = 0
//                bit3      ERR_INT_EN  = 0   (not written)
//                bits6:4   TIMEOUT_VAL = 3'b010
//                bit7      TIMEOUT_EN  = 1
//                bits31:8  reserved    = 0
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_006 steps 1-6.
//   - IP-XACT: REG_BASE=0x0000_0F00 (register block), CTRL at +0x00.
//
// NOTE: No .randomize() — fixed address/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address CTRL R/W field write-back.
// =============================================================================

class ahb_mst_test_register_access_006_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_006_seq)

  // CTRL register address (REG_BASE 0x0F00 + 0x00 offset). R/W field bits:
  //   bit0 = ENABLE, bits6:4 = TIMEOUT_VAL, bit7 = TIMEOUT_EN,
  //   bit3 = ERR_INT_EN, bit1 = SOFT_RST.
  localparam logic [31:0] CTRL_ADDR     = 32'h0000_0F00;
  // Programmed value: ENABLE=1 (bit0), TIMEOUT_VAL=0x2 (bits6:4), TIMEOUT_EN=1 (bit7).
  //   0xA9 = 1010_1001.
  localparam logic [31:0] CTRL_WR_VAL   = 32'h0000_00A9;

  function new(string name = "ahb_mst_test_register_access_006_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC006_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_006: CTRL R/W field write-back @0x%08h (write/read 0x%08h)",
                CTRL_ADDR, CTRL_WR_VAL),
      UVM_MEDIUM)

    // ── STEP 1 — WRITE CTRL = 0xA9: program ENABLE, TIMEOUT_VAL, TIMEOUT_EN ────
    // The bridge translates this AHB write into an APB write to CTRL. The R/W
    // fields latch on PREADY=1 in the ACCESS phase (XTP steps 1-3).
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_wr");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b1;    // Write
    req.wdata      = CTRL_WR_VAL;
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC006_SEQ",
      $sformatf("WRITE CTRL: HADDR=0x%08h HWDATA=0x%08h (ENABLE=1, TIMEOUT_VAL=0x2, TIMEOUT_EN=1)",
                CTRL_ADDR, CTRL_WR_VAL), UVM_HIGH)
    finish_item(req);

    // ── STEP 2 — READ CTRL: confirm R/W fields read back the programmed value ──
    // Expect PRDATA = 0x0000_00A9: bit0 ENABLE=1, bits6:4 TIMEOUT_VAL=0x2,
    // bit7 TIMEOUT_EN=1; ERR_INT_EN(bit3)=0 and SOFT_RST(bit1)=0 (not written);
    // reserved bits read 0 (XTP steps 4-6).
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_rd");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC006_SEQ",
      $sformatf("READ CTRL: HADDR=0x%08h (expect PRDATA=0x%08h: bit0=1, bits6:4=0x2, bit7=1, others 0)",
                CTRL_ADDR, CTRL_WR_VAL), UVM_HIGH)
    finish_item(req);

    // Self-check (register accesses are internal — no APB traffic to score):
    // CTRL is written unmasked by the RTL and bit1(SOFT_RST)=0 here, so the
    // read-back equals the written value exactly.
    if (req.rdata !== CTRL_WR_VAL)
      `uvm_error("REGACC006_SEQ",
        $sformatf("CTRL read-back mismatch: got 0x%08h, expected 0x%08h",
                  req.rdata, CTRL_WR_VAL))
    else
      `uvm_info("REGACC006_SEQ",
        $sformatf("CTRL R/W read-back OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC006_SEQ", "TEST_REGISTER_ACCESS_006 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_006_seq
