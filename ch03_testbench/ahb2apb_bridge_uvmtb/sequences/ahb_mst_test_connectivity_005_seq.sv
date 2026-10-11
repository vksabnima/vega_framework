// =============================================================================
// FILE: sequences/ahb_mst_test_connectivity_005_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_CONNECTIVITY_005
// DESCRIPTION: Stimulus for source_reset_connectivity.
//              Verifies HRESETn is connected: after reset deasserts, the bridge
//              returns to a known-good IDLE state and normal operation resumes.
//              The reset assertion and the reset-value sampling of source-side
//              outputs (HREADY_OUT=1, HRESP=0, HRDATA=0) and peripheral-side
//              outputs (PSEL=0, PENABLE=0, PADDR=0, PWDATA=0) are driven by the
//              tb_top reset generator and observed by the monitors. This
//              sequence supplies the post-reset register reads and the resume
//              transfer that prove normal operation continues:
//                READ CTRL       (PADDR=0x0000_0F00) expect 0x0000_0001
//                READ STATUS     (PADDR=0x0000_0F04) expect 0x0000_0001
//                READ ERROR_ADDR (PADDR=0x0000_0F08) expect 0x0000_0000
//                READ ERROR_INFO (PADDR=0x0000_0F0C) expect 0x0000_0000
//                WRITE resume    (PADDR=0x0000_4000) — FSM accepts new transfer
//
// DERIVED FROM:
//   - XTP TEST_CONNECTIVITY_005 steps 4-5 — after HRESETn=1, read example
//     registers and drive a transfer to HADDR=0x0000_4000 to prove normal
//     operation resumes (FLOW-1), confirming HRESETn connectivity (Table 8).
//   - Register block: CTRL=0xF00, STATUS=0xF04, ERROR_ADDR=0xF08, ERROR_INFO=0xF0C.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. Reset assertion and
//       reset-value sampling are performed by tb_top/monitors, not this sequence.
//
// CONFIDENCE: HIGH — straightforward post-reset register reads + resume transfer.
// =============================================================================

class ahb_mst_test_connectivity_005_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_connectivity_005_seq)

  function new(string name = "ahb_mst_test_connectivity_005_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    // Register block addresses (raw AHB transactions to PADDR 0xF00..0xF0C)
    logic [31:0] reg_addr [4];
    string       reg_name [4];
    logic [31:0] reg_exp  [4];
    int unsigned i;

    // Resume-transfer stimulus (step 5)
    logic [31:0] resume_addr = 32'h0000_4000;
    logic [31:0] resume_data = 32'hA5A5_A5A5;

    reg_addr[0] = 32'h0000_0F00; reg_name[0] = "CTRL";       reg_exp[0] = 32'h0000_0001;
    reg_addr[1] = 32'h0000_0F04; reg_name[1] = "STATUS";     reg_exp[1] = 32'h0000_0001;
    reg_addr[2] = 32'h0000_0F08; reg_name[2] = "ERROR_ADDR"; reg_exp[2] = 32'h0000_0000;
    reg_addr[3] = 32'h0000_0F0C; reg_name[3] = "ERROR_INFO"; reg_exp[3] = 32'h0000_0000;

    `uvm_info("CONN005_SEQ",
      "Starting TEST_CONNECTIVITY_005: post-reset register reads + resume transfer (HRESETn connectivity)",
      UVM_MEDIUM)

    // ── Step 4 — read example registers after HRESETn deassertion ───────────
    // Documented reset values (Table 8): CTRL=0x1, STATUS=0x1, ERROR_*=0x0.
    for (i = 0; i < 4; i++) begin
      req = ahb_mst_seq_item::type_id::create($sformatf("ahb_conn005_rd_%s", reg_name[i]));
      start_item(req);
      req.addr       = reg_addr[i];
      req.write      = 1'b0;    // Read register
      req.wdata      = 32'h0;   // unused for reads
      req.trans_type = 2'b10;   // NONSEQ
      req.burst      = 3'b000;  // SINGLE
      req.size       = 3'b010;  // Word (32-bit)
      req.post_randomize();
      `uvm_info("CONN005_SEQ",
        $sformatf("READ %s: PADDR=0x%08h expect 0x%08h", reg_name[i], reg_addr[i], reg_exp[i]),
        UVM_HIGH)
      finish_item(req);
    end

    // ── Step 5 — drive a transfer to prove normal operation resumes ─────────
    // FSM must accept a new transfer (FLOW-1) after reset, proving HRESETn
    // connectivity once reset values matched Table 8.
    req = ahb_mst_seq_item::type_id::create("ahb_conn005_resume_wr");
    start_item(req);
    req.addr       = resume_addr;
    req.write      = 1'b1;    // Write — drive HSEL=1, HTRANS=2'b10, HADDR=0x4000
    req.wdata      = resume_data;
    req.trans_type = 2'b10;   // NONSEQ — new transfer
    req.burst      = 3'b000;  // SINGLE
    req.size       = 3'b010;  // Word (32-bit)
    req.post_randomize();
    `uvm_info("CONN005_SEQ",
      $sformatf("RESUME WRITE: HADDR=0x%08h HWDATA=0x%08h (expect FSM accepts new transfer, FLOW-1)",
                resume_addr, resume_data), UVM_HIGH)
    finish_item(req);

    `uvm_info("CONN005_SEQ", "TEST_CONNECTIVITY_005 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_connectivity_005_seq
