// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_001
// DESCRIPTION: Stimulus for status_reset_value_check.
//              Verifies the STATUS register reflects its specified reset state
//              with READY asserted and no sticky errors set.
//
//              After reset the bridge is idle. The sequence issues a single
//              word READ of the STATUS register (REG_BASE + 0x04 = 0x0000_0F04)
//              through the AHB master. The read propagates through the bridge as
//              an APB SETUP+ACCESS read; PRDATA is expected to be 0x0000_0001
//              (READY=bit0=1, BUSY=bit1=0, all sticky error flags =0).
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_001 steps 3-5 — APB read of STATUS @0xF04,
//     verify PRDATA == 0x0000_0001 after reset.
//   - IP-XACT: REG_BASE=0x0000_0F00 (register block).
//
// NOTE: No .randomize() — fixed address per [TC1].
//
// CONFIDENCE: HIGH — single fixed-address register read after reset.
// =============================================================================

class ahb_mst_test_register_access_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_001_seq)

  // STATUS register address (REG_BASE 0x0F00 + 0x04 offset) and its expected
  // reset value (READY=1, BUSY=0, ERR_INT/TIMEOUT_ERR/PSLVERR/ADDR_ERR all 0).
  localparam logic [31:0] STATUS_ADDR        = 32'h0000_0F04;
  localparam logic [31:0] STATUS_RESET_VALUE = 32'h0000_0001;

  function new(string name = "ahb_mst_test_register_access_001_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC001_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_001: READ STATUS @0x%08h (expect 0x%08h)",
                STATUS_ADDR, STATUS_RESET_VALUE),
      UVM_MEDIUM)

    // Single word READ of the STATUS register — bridge translates to an APB
    // SETUP+ACCESS read and returns PRDATA on HRDATA.
    req = ahb_mst_seq_item::type_id::create("ahb_regacc_rd");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read — STATUS is read-only after reset
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit), HSIZE=3'b010
    req.post_randomize();
    `uvm_info("REGACC001_SEQ",
      $sformatf("READ STATUS: HADDR=0x%08h (expect HRDATA=0x%08h)",
                STATUS_ADDR, STATUS_RESET_VALUE), UVM_HIGH)
    finish_item(req);

    // Self-check: register reads are serviced internally by the bridge
    // (ST_REG_READ) and produce NO APB traffic, so the AHB<->APB scoreboard
    // cannot verify them. Check the read-back value the driver captured here.
    if (req.resp !== 1'b0)
      `uvm_error("REGACC001_SEQ",
        $sformatf("STATUS read returned HRESP=%0b, expected OKAY(0)", req.resp))
    if (req.rdata !== STATUS_RESET_VALUE)
      `uvm_error("REGACC001_SEQ",
        $sformatf("STATUS reset-value mismatch: got HRDATA=0x%08h, expected 0x%08h",
                  req.rdata, STATUS_RESET_VALUE))
    else
      `uvm_info("REGACC001_SEQ",
        $sformatf("STATUS reset value OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC001_SEQ", "TEST_REGISTER_ACCESS_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_001_seq
