// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_015_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_015
// DESCRIPTION: Stimulus for hresp_error_on_target_pslverr.
//              Drives a single accepted source-side (AHB) NONSEQ read request to
//              0x0000_2000 so the bridge walks a normal transfer until the target
//              active phase, where the reactive APB slave asserts PSLVERR=1. The
//              bridge must then drive HRESP=1 (error) on the source side coincident
//              with HREADY_OUT=1 at completion. Flow produced by the bridge FSM and
//              the reactive APB slave (PSLVERR=1 injected during ACTIVE):
//                T1 (FLOW-1, capture) : accepted request presented (HSEL=1,
//                                       HTRANS=NONSEQ, HWRITE=0, HADDR=0x0000_2000,
//                                       HSIZE=word, HREADY_IN=1); address/control
//                                       latched, HRESP=0 initially
//                T2 (FLOW-2, SETUP)   : PSEL=1, PENABLE=0, PWRITE=0,
//                                       PADDR=0x0000_2000; HRESP still 0
//                T3 (FLOW-3, ACTIVE)  : PSEL=1, PENABLE=1; slave drives PREADY=1,
//                                       PSLVERR=1 (target error injected)
//                T4 (FLOW-5, complete): HREADY_OUT=1, HRESP=1 (error); completion
//                                       gated by target ready, error indicated
//              Follow-up register reads then confirm the sticky log:
//                - STATUS  read at 0xF04 — PSLVERR sticky bit[5]=1
//                - ERROR_ADDR read at 0xF08 — captured = 0x0000_2000
//
//              Transfers:
//                1. WRITE — CTRL enable (0xF00 <= 0x0000_0001), precondition
//                2. READ  — HTRANS=NONSEQ, HWRITE=0, HSIZE=word, HADDR=0x0000_2000
//                           (target error injection point, expect HRESP=1)
//                3. READ  — STATUS register read-back (0xF04), expect bit[5]=1
//                4. READ  — ERROR_ADDR register read-back (0xF08), expect 0x0000_2000
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_015 steps 1-5 — confirm HRESP=1 driven on source side when
//     PSLVERR=1, HRESP transitions to error only during/after the target active
//     phase, STATUS.PSLVERR (bit5) latched sticky, ERROR_ADDR captured = 0x0000_2000,
//     and HREADY_OUT=1 gates the error indication.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all register
//       accesses are raw AHB transactions to the control/status block at
//       0xF00..0xF0C. The PSEL/PENABLE/PREADY phase timing, PSLVERR=1 target-error
//       injection, source-side HRESP=1 response, and HREADY_OUT completion gating
//       are produced by the bridge FSM and the reactive APB slave and observed by
//       the monitors; this sequence only presents the accepted AHB requests.
//
// CONFIDENCE: HIGH — single NONSEQ read at the error address plus register read-backs.
// =============================================================================

class ahb_mst_test_protocol_015_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_015_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;  // CTRL (ENABLE bit0)
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;  // STATUS (PSLVERR bit5)
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;  // captured error address

  // ── Stimulus values ──────────────────────────────────────────────────────
  localparam logic [31:0] CTRL_ENABLE    = 32'h0000_0001;  // ENABLE=1 (precondition)
  localparam logic [31:0] TEST_ADDR      = 32'h0000_2000;  // target-error read address

  function new(string name = "ahb_mst_test_protocol_015_seq");
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
    `uvm_info("PROTO015_SEQ",
      $sformatf("WRITE %s: addr=0x%08h data=0x%08h", tag, addr, data), UVM_HIGH)
    finish_item(req);
  endtask : do_write

  // ── Helper: drive a single word READ transaction ──────────────────────────
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
    `uvm_info("PROTO015_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("PROTO015_SEQ",
      "Starting TEST_PROTOCOL_015: present an accepted AHB read request to 0x0000_2000; the reactive APB slave injects PSLVERR=1 during the target active phase; the bridge must drive source-side HRESP=1 (error) coincident with HREADY_OUT=1; STATUS.PSLVERR (bit5) latches sticky and ERROR_ADDR captures 0x0000_2000",
      UVM_MEDIUM)

    // ── T0: precondition — enable the bridge (CTRL.ENABLE=1) ──────────────────
    do_write(REG_CTRL, CTRL_ENABLE, "ctrl_enable");

    // ── T1-T4: accepted NONSEQ READ to the target-error address ───────────────
    // Presenting this accepted read drives the FSM through source capture
    // (address/control latched, HRESP=0 initially), target SETUP (PSEL=1,
    // PENABLE=0, PWRITE=0, PADDR=0x0000_2000), then target ACTIVE (PSEL=1,
    // PENABLE=1). The reactive APB slave drives PREADY=1 with PSLVERR=1 to inject
    // a target error, so source-side completion shows HREADY_OUT=1 with HRESP=1.
    do_read(TEST_ADDR, "err_read");

    // ── T5: STATUS read-back (0xF04) — PSLVERR sticky bit[5]=1 ────────────────
    do_read(REG_STATUS, "status_err");

    // ── T5: ERROR_ADDR read-back (0xF08) — captured = 0x0000_2000 ─────────────
    do_read(REG_ERROR_ADDR, "erraddr_capt");

    `uvm_info("PROTO015_SEQ", "TEST_PROTOCOL_015 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_015_seq
