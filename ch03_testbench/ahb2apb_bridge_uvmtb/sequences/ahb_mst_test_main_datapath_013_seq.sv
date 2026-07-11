// =============================================================================
// FILE: sequences/ahb_mst_test_main_datapath_013_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_MAIN_DATAPATH_013
// DESCRIPTION: Stimulus for timeout_during_persistent_stall. Programs the bridge
//              control register to enable the back-pressure timeout, then issues a
//              single source write whose APB target transfer is held by a
//              persistent PREADY=0 stall. With TIMEOUT_EN=1 / TIMEOUT_VAL=3'b111
//              the bridge must hold HREADY_OUT low for the entire timeout window
//              (PENABLE stays 1, transfer kept active) and, when the programmed
//              timeout window elapses, terminate the held transfer with
//              HREADY_OUT=1 / HRESP=1 and set STATUS.TIMEOUT_ERR (bit 6) sticky
//              with ERROR_ADDR capturing the offending address.
//
//              Register / stimulus map (raw AHB transactions, [TC] register block
//              REG_BASE=0x0000_0F00):
//                T1 : WRITE CTRL  (0x0000_0F00) = 0x0000_00F1   (ENABLE=1,
//                                                  TIMEOUT_EN=1, TIMEOUT_VAL=111)
//                     READ  CTRL  (0x0000_0F00) -> expect 0x0000_00F1
//                T2 : WRITE src   (0x0000_4000) = 0x1234_5678   (held by stall)
//                T6 : READ  STATUS    (0x0000_0F04) -> expect TIMEOUT_ERR/ERR_INT
//                     READ  ERROR_ADDR (0x0000_0F08) -> expect 0x0000_4000
//
// DERIVED FROM:
//   - XTP TEST_MAIN_DATAPATH_013 steps 1-6 — back_pressure_wait_behavior. The
//     persistent PREADY=0 stall is produced by the passive APB slave agent; the
//     timeout / HRESP=1 / STATUS.TIMEOUT_ERR behaviour is a property of the
//     bridge FSM observed by the monitors.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. Register accesses go
//       through this AHB master sequence as raw transactions to PADDR 0xF00..0xF0C.
//
// CONFIDENCE: HIGH — fixed-address register program + single held write.
// =============================================================================

class ahb_mst_test_main_datapath_013_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_main_datapath_013_seq)

  // Register block addresses (REG_BASE = 0x0000_0F00).
  localparam logic [31:0] CTRL_ADDR       = 32'h0000_0F00;
  localparam logic [31:0] STATUS_ADDR     = 32'h0000_0F04;
  localparam logic [31:0] ERROR_ADDR_ADDR = 32'h0000_0F08;

  // CTRL program: ENABLE=1, TIMEOUT_EN=1, TIMEOUT_VAL=3'b111.
  localparam logic [31:0] CTRL_VAL = 32'h0000_00F1;

  // Source write held by the persistent PREADY=0 stall.
  localparam logic [31:0] SRC_ADDR = 32'h0000_4000;
  localparam logic [31:0] SRC_DATA = 32'h1234_5678;

  function new(string name = "ahb_mst_test_main_datapath_013_seq");
    super.new(name);
  endfunction : new

  task body();
    ahb_mst_seq_item req;

    `uvm_info("DP013_SEQ",
      "Starting TEST_MAIN_DATAPATH_013: enable timeout, then a persistently stalled write",
      UVM_MEDIUM)

    // ── STEP 1 — program CTRL to enable the back-pressure timeout ─────────────
    req = ahb_mst_seq_item::type_id::create("ahb_dp013_ctrl_wr");
    start_item(req);
    req.addr       = CTRL_ADDR;   // HADDR=0x0000_0F00 (CTRL)
    req.write      = 1'b1;        // HWRITE=1 (write)
    req.wdata      = CTRL_VAL;    // ENABLE=1, TIMEOUT_EN=1, TIMEOUT_VAL=111
    req.trans_type = 2'b10;       // HTRANS=NONSEQ
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word
    `uvm_info("DP013_SEQ",
      $sformatf("WRITE CTRL: HADDR=0x%08h HWDATA=0x%08h", CTRL_ADDR, CTRL_VAL),
      UVM_HIGH)
    finish_item(req);

    // ── STEP 1 (read-back) — confirm CTRL == 0x0000_00F1 ─────────────────────
    req = ahb_mst_seq_item::type_id::create("ahb_dp013_ctrl_rd");
    start_item(req);
    req.addr       = CTRL_ADDR;   // HADDR=0x0000_0F00 (CTRL)
    req.write      = 1'b0;        // HWRITE=0 (read-back)
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // HTRANS=NONSEQ
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word
    `uvm_info("DP013_SEQ",
      $sformatf("READ  CTRL: HADDR=0x%08h expect 0x%08h", CTRL_ADDR, CTRL_VAL),
      UVM_HIGH)
    finish_item(req);

    // ── STEP 2 — source write held active by the persistent PREADY=0 stall ───
    // The APB slave holds PREADY=0 continuously; the bridge keeps the transfer
    // active (PSEL=1, PENABLE=1, HREADY_OUT=0) until the programmed timeout
    // window elapses, then terminates with HREADY_OUT=1 / HRESP=1.
    req = ahb_mst_seq_item::type_id::create("ahb_dp013_src_wr");
    start_item(req);
    req.addr       = SRC_ADDR;    // HADDR=0x0000_4000
    req.write      = 1'b1;        // HWRITE=1 (write)
    req.wdata      = SRC_DATA;    // HWDATA=0x1234_5678
    req.trans_type = 2'b10;       // HTRANS=NONSEQ
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word
    `uvm_info("DP013_SEQ",
      $sformatf("WRITE src: HADDR=0x%08h HWDATA=0x%08h (held by stall)", SRC_ADDR, SRC_DATA),
      UVM_HIGH)
    finish_item(req);

    // ── STEP 6 — read STATUS (TIMEOUT_ERR/ERR_INT) and ERROR_ADDR ────────────
    req = ahb_mst_seq_item::type_id::create("ahb_dp013_status_rd");
    start_item(req);
    req.addr       = STATUS_ADDR; // HADDR=0x0000_0F04 (STATUS)
    req.write      = 1'b0;        // HWRITE=0 (read)
    req.wdata      = 32'h0;       // unused for reads
    req.trans_type = 2'b10;       // HTRANS=NONSEQ
    req.burst      = 3'b000;      // HBURST=SINGLE
    req.size       = 3'b010;      // HSIZE=word
    `uvm_info("DP013_SEQ",
      $sformatf("READ  STATUS: HADDR=0x%08h expect TIMEOUT_ERR(bit6)/ERR_INT set", STATUS_ADDR),
      UVM_HIGH)
    finish_item(req);
    // CTRL=0xF1 has ERR_INT_EN=0, so STATUS = READY(b0)|TIMEOUT_ERR(b6) = 0x41.
    if (req.rdata !== 32'h0000_0041)
      `uvm_error("DP013_SEQ",
        $sformatf("STATUS after timeout mismatch: got 0x%08h, expected 0x00000041", req.rdata))
    else
      `uvm_info("DP013_SEQ", $sformatf("STATUS TIMEOUT_ERR OK: 0x%08h", req.rdata), UVM_LOW)

    req = ahb_mst_seq_item::type_id::create("ahb_dp013_erraddr_rd");
    start_item(req);
    req.addr       = ERROR_ADDR_ADDR; // HADDR=0x0000_0F08 (ERROR_ADDR)
    req.write      = 1'b0;            // HWRITE=0 (read)
    req.wdata      = 32'h0;           // unused for reads
    req.trans_type = 2'b10;           // HTRANS=NONSEQ
    req.burst      = 3'b000;          // HBURST=SINGLE
    req.size       = 3'b010;          // HSIZE=word
    `uvm_info("DP013_SEQ",
      $sformatf("READ  ERROR_ADDR: HADDR=0x%08h expect 0x%08h", ERROR_ADDR_ADDR, SRC_ADDR),
      UVM_HIGH)
    finish_item(req);
    if (req.rdata !== SRC_ADDR)
      `uvm_error("DP013_SEQ",
        $sformatf("ERROR_ADDR mismatch: got 0x%08h, expected 0x%08h", req.rdata, SRC_ADDR))
    else
      `uvm_info("DP013_SEQ", $sformatf("ERROR_ADDR captured OK: 0x%08h", req.rdata), UVM_LOW)

    `uvm_info("DP013_SEQ", "TEST_MAIN_DATAPATH_013 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_main_datapath_013_seq
