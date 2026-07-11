// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_002_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_002
// DESCRIPTION: Stimulus for status_sticky_error_set_on_target_error.
//              Verifies PSLVERR and aggregated ERR_INT sticky bits in the STATUS
//              register are set and preserved after a target error event.
//
//              Drives, through the AHB master:
//                1. A source-side WRITE to 0x0000_0200 (HWDATA=0x0000_DA7A). The
//                   bridge forwards this to the APB target; the reactive APB
//                   slave is driven to assert PSLVERR=1, injecting a target error
//                   that the bridge returns as HRESP=1 and latches as the sticky
//                   PSLVERR / aggregated ERR_INT bits in STATUS.
//                2. A READ of STATUS @0x0000_0F04 — expect PRDATA[5]=PSLVERR=1
//                   and PRDATA[7]=ERR_INT=1.
//                3. A second READ of STATUS @0x0000_0F04 without any W1C clear —
//                   the sticky bits must persist (still bit5=1, bit7=1).
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_002 steps 1-5.
//   - IP-XACT: REG_BASE=0x0000_0F00 (register block), STATUS at +0x04.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address write (error) then two STATUS reads.
// =============================================================================

class ahb_mst_test_register_access_002_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_002_seq)

  // STATUS register address (REG_BASE 0x0F00 + 0x04 offset). Sticky bits:
  //   bit5 = PSLVERR, bit7 = ERR_INT (aggregated error interrupt).
  localparam logic [31:0] STATUS_ADDR    = 32'h0000_0F04;
  localparam logic [31:0] CTRL_ADDR      = 32'h0000_0F00;
  // ENABLE=1 (bit0) so the transfer forwards, ERR_INT_EN=1 (bit3) so the
  // aggregated STATUS.ERR_INT bit can set on error. 0x09 = 0000_1001.
  localparam logic [31:0] CTRL_CFG       = 32'h0000_0009;
  // Source-side target address used to provoke the target error event. The test
  // configures the reactive APB slave (cfg.add_apb_err_addr) to return PSLVERR
  // for this address.
  localparam logic [31:0] ERR_TXN_ADDR   = 32'h0000_0200;
  localparam logic [31:0] ERR_TXN_WDATA  = 32'h0000_DA7A;
  // Expected STATUS after the target error: READY(b0)=1, PSLVERR(b5)=1,
  // ERR_INT(b7)=1 -> 0x0000_00A1.
  localparam logic [31:0] STATUS_ERR_EXP = 32'h0000_00A1;

  function new(string name = "ahb_mst_test_register_access_002_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC002_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_002: WRITE @0x%08h (provoke target error) then read STATUS @0x%08h x2",
                ERR_TXN_ADDR, STATUS_ADDR),
      UVM_MEDIUM)

    // ── STEP 0 — configure CTRL: ENABLE + ERR_INT_EN ─────────────────────────
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_cfg");
    start_item(req);
    req.addr = CTRL_ADDR; req.write = 1'b1; req.wdata = CTRL_CFG;
    req.trans_type = 2'b10; req.burst = 3'b000; req.size = 3'b010;
    req.post_randomize();
    finish_item(req);

    // ── STEP 1-2 — source-side WRITE that triggers a target error ────────────
    // The bridge forwards this to the APB target where PSLVERR is injected;
    // HRESP=1 is returned and the sticky PSLVERR/ERR_INT bits latch in STATUS.
    req = ahb_mst_seq_item::type_id::create("ahb_err_wr");
    start_item(req);
    req.addr       = ERR_TXN_ADDR;
    req.write      = 1'b1;    // Write — source-side transfer
    req.wdata      = ERR_TXN_WDATA;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC002_SEQ",
      $sformatf("WRITE (error txn): HADDR=0x%08h HWDATA=0x%08h (expect HRESP=1)",
                ERR_TXN_ADDR, ERR_TXN_WDATA), UVM_HIGH)
    finish_item(req);

    // Self-check: the injected target error must return HRESP=ERROR(1).
    if (req.resp !== 1'b1)
      `uvm_error("REGACC002_SEQ",
        $sformatf("Target-error write should return HRESP=1, got %0b", req.resp))

    // ── STEP 3-4 — READ STATUS, expect sticky PSLVERR & ERR_INT set ──────────
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd1");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC002_SEQ",
      $sformatf("READ STATUS #1: HADDR=0x%08h (expect PRDATA[5]=PSLVERR=1, PRDATA[7]=ERR_INT=1)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);

    // Self-check: sticky PSLVERR (bit5) + aggregated ERR_INT (bit7) set, READY=1.
    if (req.rdata !== STATUS_ERR_EXP)
      `uvm_error("REGACC002_SEQ",
        $sformatf("STATUS after target error mismatch: got 0x%08h, expected 0x%08h (READY|PSLVERR|ERR_INT)",
                  req.rdata, STATUS_ERR_EXP))
    else
      `uvm_info("REGACC002_SEQ",
        $sformatf("STATUS sticky PSLVERR/ERR_INT set OK: 0x%08h", req.rdata), UVM_LOW)

    // ── STEP 5 — RE-READ STATUS without clear, sticky bits must persist ──────
    req = ahb_mst_seq_item::type_id::create("ahb_status_rd2");
    start_item(req);
    req.addr       = STATUS_ADDR;
    req.write      = 1'b0;    // Read — no W1C clear performed
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC002_SEQ",
      $sformatf("READ STATUS #2: HADDR=0x%08h (expect PRDATA[5]=1, PRDATA[7]=1 still set — sticky)",
                STATUS_ADDR), UVM_HIGH)
    finish_item(req);

    // Self-check: no W1C clear was issued, so the sticky bits must persist.
    if (req.rdata !== STATUS_ERR_EXP)
      `uvm_error("REGACC002_SEQ",
        $sformatf("STATUS sticky bits not preserved: got 0x%08h, expected 0x%08h",
                  req.rdata, STATUS_ERR_EXP))
    else
      `uvm_info("REGACC002_SEQ",
        $sformatf("STATUS sticky bits preserved OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC002_SEQ", "TEST_REGISTER_ACCESS_002 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_002_seq
