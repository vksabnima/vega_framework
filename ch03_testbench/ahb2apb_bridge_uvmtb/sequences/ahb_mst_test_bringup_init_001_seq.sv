// =============================================================================
// FILE: sequences/ahb_mst_test_bringup_init_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_BRINGUP_INIT_001
// DESCRIPTION: Stimulus for single_clock_domain_reset_bringup.
//              After reset deassertion, reads back the documented reset-state
//              registers through the AHB master as raw transactions to the
//              register block (PADDR 0xF00..0xF0C):
//                CTRL       (0xF00) — expect 0x0000_0001 per Table 8
//                STATUS     (0xF04) — expect 0x0000_0001 per Table 8
//                ERROR_ADDR (0xF08) — expect 0x0000_0000 (cleared)
//                ERROR_INFO (0xF0C) — expect 0x0000_0000 (cleared)
//
// DERIVED FROM:
//   - XTP TEST_BRINGUP_INIT_001 steps 5 and 6 — read CTRL/STATUS and the
//     debug capture registers and compare against documented reset values.
//
// NOTE: No .randomize() — fixed addresses per [TC1]. Reads only.
//
// CONFIDENCE: HIGH — straightforward register read-back stimulus.
// =============================================================================

class ahb_mst_test_bringup_init_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_bringup_init_001_seq)

  // Documented reset-state register addresses (Table 8).
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;
  localparam logic [31:0] REG_ERROR_INFO = 32'h0000_0F0C;

  function new(string name = "ahb_mst_test_bringup_init_001_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;
    logic [31:0] reg_addr [4];

    reg_addr[0] = REG_CTRL;
    reg_addr[1] = REG_STATUS;
    reg_addr[2] = REG_ERROR_ADDR;
    reg_addr[3] = REG_ERROR_INFO;

    `uvm_info("INIT001_SEQ",
      "Starting TEST_BRINGUP_INIT_001: read back reset-state registers 0xF00..0xF0C",
      UVM_MEDIUM)

    // Read each documented reset-state register through the AHB master.
    foreach (reg_addr[i]) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_reg_rd_%0d", i));
      start_item(req);
      req.addr       = reg_addr[i];
      req.write      = 1'b0;    // Read
      req.wdata      = 32'h0;   // unused for reads
      req.trans_type = 2'b10;   // NONSEQ
      req.burst      = 3'b000;  // SINGLE
      req.size       = 3'b010;  // Word (32-bit)
      req.post_randomize();
      `uvm_info("INIT001_SEQ",
        $sformatf("READ reset-state reg[%0d]: addr=0x%08h", i, reg_addr[i]), UVM_HIGH)
      finish_item(req);
    end

    `uvm_info("INIT001_SEQ", "TEST_BRINGUP_INIT_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_bringup_init_001_seq
