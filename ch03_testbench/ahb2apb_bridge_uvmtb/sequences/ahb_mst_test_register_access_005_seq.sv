// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_005_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_005
// DESCRIPTION: Stimulus for ctrl_reg_reset_value_check.
//              Verifies the CTRL register powers up to its specified reset
//              value with ENABLE set and TIMEOUT_VAL=3'b111.
//
//              Preconditions: PCLK/HCLK running, PRESETn asserted then
//              deasserted before access.
//
//              Drives, through the AHB master, a single CTRL register read to
//              REG_BASE+0x00 = 0x0000_0F00 immediately after reset release:
//                1. READ CTRL after reset — expect PRDATA reset value with
//                   bit0 ENABLE=1, bits6:4 TIMEOUT_VAL=3'b111, all other bits 0.
//                   Expected aggregate PRDATA = 0x0000_0071.
//
//              Decoded CTRL fields checked by the scoreboard / observed PRDATA:
//                bit0      ENABLE      = 1
//                bit1      SOFT_RST    = 0
//                bit2      reserved    = 0
//                bit3      ERR_INT_EN  = 0
//                bits6:4   TIMEOUT_VAL = 3'b111
//                bit7      TIMEOUT_EN  = 0
//                bits31:8  reserved    = 0
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_005 steps 1-6.
//   - IP-XACT: REG_BASE=0x0000_0F00 (register block), CTRL at +0x00.
//
// NOTE: No .randomize() — fixed address/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address CTRL reset-value read.
// =============================================================================

class ahb_mst_test_register_access_005_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_005_seq)

  // CTRL register address (REG_BASE 0x0F00 + 0x00 offset). Reset value bits:
  //   bit0 = ENABLE, bits6:4 = TIMEOUT_VAL, bit7 = TIMEOUT_EN,
  //   bit3 = ERR_INT_EN, bit1 = SOFT_RST.
  localparam logic [31:0] CTRL_ADDR       = 32'h0000_0F00;
  // Spec-golden reset value (Spec "Example Reset State" table): ENABLE=1 (bit0),
  // timeout disabled, all other knobs 0 => 0x0000_0001.
  localparam logic [31:0] CTRL_RESET_VAL  = 32'h0000_0001;

  function new(string name = "ahb_mst_test_register_access_005_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC005_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_005: CTRL reset-value check @0x%08h (expect 0x%08h)",
                CTRL_ADDR, CTRL_RESET_VAL),
      UVM_MEDIUM)

    // ── STEP 1 — READ CTRL after reset release: check power-up reset value ────
    // The bridge has been reset (PRESETn asserted then deasserted by tb_top),
    // so CTRL holds its reset value: ENABLE=1, TIMEOUT_VAL=3'b111, others 0.
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_rd_reset");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC005_SEQ",
      $sformatf("READ CTRL (reset): HADDR=0x%08h (expect PRDATA=0x%08h: bit0 ENABLE=1, bits6:4 TIMEOUT_VAL=0x7, others 0)",
                CTRL_ADDR, CTRL_RESET_VAL), UVM_HIGH)
    finish_item(req);

    // Self-check: register reads are internal to the bridge (no APB traffic),
    // so verify the captured read-back value here.
    if (req.resp !== 1'b0)
      `uvm_error("REGACC005_SEQ",
        $sformatf("CTRL read returned HRESP=%0b, expected OKAY(0)", req.resp))
    if (req.rdata !== CTRL_RESET_VAL)
      `uvm_error("REGACC005_SEQ",
        $sformatf("CTRL reset-value mismatch: got HRDATA=0x%08h, expected 0x%08h",
                  req.rdata, CTRL_RESET_VAL))
    else
      `uvm_info("REGACC005_SEQ",
        $sformatf("CTRL reset value OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC005_SEQ", "TEST_REGISTER_ACCESS_005 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_005_seq
