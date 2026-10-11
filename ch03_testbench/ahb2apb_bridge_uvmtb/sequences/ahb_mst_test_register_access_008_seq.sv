// =============================================================================
// FILE: sequences/ahb_mst_test_register_access_008_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_REGISTER_ACCESS_008
// DESCRIPTION: Stimulus for ctrl_reserved_bits_readonly_check.
//              Verifies that the CTRL reserved bits remain 0 and are unaffected
//              by an attempted write of all-ones, while the writable fields take
//              the written value (subject to SOFT_RST self-clear).
//
//              Preconditions: PCLK running, PRESETn deasserted, CTRL at reset
//              value 0x0000_0001.
//
//              Drives, through the AHB master, the following transfers to the
//              register block (REG_BASE = 0x0000_0F00):
//                1. WRITE CTRL @0x0F00 = 0xFFFF_FFFF — attempt to set every bit,
//                     including reserved positions (XTP steps 1-3). The bridge
//                     translates this into an APB write; only the writable fields
//                     latch, reserved bits stay RO=0.
//                2. READ  CTRL @0x0F00 — read back to confirm reserved bits read
//                     0 and writable bits reflect the written ones (XTP steps
//                     4-6).
//
//              Expected read-back (XTP PASS CRITERIA):
//                bits31:8 reserved   = 0x000000  (RO=0, unaffected by write)
//                bit7     TIMEOUT_EN = 1
//                bits6:4             = 0x7
//                bit3     ERR_INT_EN = 1
//                bit2     reserved   = 0          (RO=0)
//                bit1     SOFT_RST   = 1 attempt  (self-clearing)
//                bit0     ENABLE     = 1
//
// DERIVED FROM:
//   - XTP TEST_REGISTER_ACCESS_008 steps 1-6.
//   - IP-XACT: REG_BASE=0x0000_0F00 (CTRL at +0x00).
//
// NOTE: No .randomize() — fixed address/data per [TC1].
//
// CONFIDENCE: HIGH — fixed-address CTRL all-ones write then read-back.
// =============================================================================

class ahb_mst_test_register_access_008_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_register_access_008_seq)

  // Register block addresses (REG_BASE 0x0F00).
  //   CTRL at +0x00 : bit0 ENABLE, bit1 SOFT_RST, bit3 ERR_INT_EN,
  //                   bits6:4, bit7 TIMEOUT_EN; bit2 and bits31:8 reserved RO=0.
  localparam logic [31:0] CTRL_ADDR    = 32'h0000_0F00;
  // Attempted write value: all ones — exercises reserved positions too.
  localparam logic [31:0] CTRL_WR_VAL  = 32'hFFFF_FFFF;

  function new(string name = "ahb_mst_test_register_access_008_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("REGACC008_SEQ",
      $sformatf("Starting TEST_REGISTER_ACCESS_008: CTRL reserved-bits read-only check (CTRL@0x%08h, write 0x%08h)",
                CTRL_ADDR, CTRL_WR_VAL),
      UVM_MEDIUM)

    // ── STEP 1-3 — WRITE CTRL = 0xFFFFFFFF: attempt to set all bits ────────────
    // The bridge translates this AHB write into an APB write to CTRL. The write
    // commits to writable fields only on PREADY=1 in the ACCESS phase; reserved
    // positions remain RO=0 (XTP steps 1-3).
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_wr_allones");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b1;    // Write
    req.wdata      = CTRL_WR_VAL;
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC008_SEQ",
      $sformatf("WRITE CTRL: HADDR=0x%08h HWDATA=0x%08h (attempt all-ones incl. reserved)",
                CTRL_ADDR, CTRL_WR_VAL), UVM_HIGH)
    finish_item(req);

    // ── STEP 4-6 — READ CTRL: confirm reserved bits read 0, writable bits set ──
    // Expect bits31:8=0, bit2=0 (reserved RO=0); bit7 TIMEOUT_EN=1, bits6:4=0x7,
    // bit3 ERR_INT_EN=1, bit1 SOFT_RST=1(attempt, self-clearing), bit0 ENABLE=1
    // (XTP steps 4-6).
    req = ahb_mst_seq_item::type_id::create("ahb_ctrl_rd");
    start_item(req);
    req.addr       = CTRL_ADDR;
    req.write      = 1'b0;    // Read
    req.wdata      = 32'h0;   // unused for reads
    req.trans_type = 2'b10;   // NONSEQ
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("REGACC008_SEQ",
      $sformatf("READ CTRL: HADDR=0x%08h (expect bits31:8=0, bit2=0; writable bits set)",
                CTRL_ADDR), UVM_HIGH)
    finish_item(req);

    // Self-check (register access is internal — no APB traffic to score).
    // Spec Table 5: CTRL reserved bits [31:8] and bit2 are RO=0 and ignore
    // writes; the writable set is mask 0xFB. So writing all-ones lands as
    // 0xFB, then bit1 (SOFT_RST) self-clears => read-back 0x0000_00F9.
    if (req.rdata !== 32'h0000_00F9)
      `uvm_error("REGACC008_SEQ",
        $sformatf("CTRL all-ones read-back mismatch: got 0x%08h, expected 0x%08h (reserved bits RO, bit1 self-clears)",
                  req.rdata, 32'h0000_00F9))
    else
      `uvm_info("REGACC008_SEQ",
        $sformatf("CTRL reserved-bit RO + write-mask OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("REGACC008_SEQ", "TEST_REGISTER_ACCESS_008 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_register_access_008_seq
