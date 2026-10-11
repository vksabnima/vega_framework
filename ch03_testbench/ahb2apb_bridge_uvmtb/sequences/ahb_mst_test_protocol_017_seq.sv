// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_017_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_017
// DESCRIPTION: Stimulus for hresp_ok_stable_during_wait_states.
//              Programs CTRL with TIMEOUT_EN=0 (no timeout) and ENABLE=1 =>
//              CTRL=0x0000_0001 (precondition), then drives a single accepted
//              source-side (AHB) NONSEQ READ request to 0x0000_4000. The reactive
//              APB slave holds PREADY=0 for several cycles (target wait states)
//              before completing the transfer with PREADY=1, PSLVERR=0 and
//              PRDATA=0xCAFE_0001. Throughout the wait window the bridge must keep
//              HRESP=0 (no premature/spurious error) and only resolve to OK with
//              HRDATA=0xCAFE_0001 at completion. Flow produced by the bridge FSM
//              and the reactive APB slave (PREADY held low during ACTIVE):
//                T1 (FLOW-1, capture) : accepted request presented (HSEL=1,
//                                       HTRANS=NONSEQ, HWRITE=0 (read),
//                                       HADDR=0x0000_4000, HSIZE=word, HREADY_IN=1);
//                                       address/control latched, HRESP=0
//                T2 (FLOW-2, SETUP)   : PSEL=1, PENABLE=0, PADDR=0x0000_4000;
//                                       HRESP still 0
//                T3 (FLOW-4, ACTIVE)  : PSEL=1, PENABLE=1; slave holds PREADY=0,
//                                       PSLVERR=0 (stall); HREADY_OUT=0, HRESP=0
//                T4..T5 (stall)       : PREADY=0 held; HRESP=0 stable each rising
//                                       edge (no spurious error pulse); PADDR stable
//                T6 (FLOW-5, complete): PREADY=1, PSLVERR=0, PRDATA=0xCAFE_0001 =>
//                                       HREADY_OUT=1, HRESP=0, HRDATA=0xCAFE_0001
//              Follow-up register read then confirms no sticky error was logged:
//                - STATUS read at 0xF04 — STATUS=0x0000_0001 (no error bits set)
//
//              Transfers:
//                1. WRITE — CTRL program (0xF00 <= 0x0000_0001): TIMEOUT_EN=0,
//                           ENABLE(bit0)=1 (precondition)
//                2. READ  — HTRANS=NONSEQ, HWRITE=0, HSIZE=word, HADDR=0x0000_4000
//                           (wait-state read, expect HRESP=0 stable, HRDATA=0xCAFE_0001)
//                3. READ  — STATUS register read-back (0xF04), expect no sticky error
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_017 steps 1-6 — confirm HRESP=0 stable for every wait cycle
//     (T3..T5), no spurious HRESP=1 during stall, HREADY_OUT=0 during wait then =1 at
//     completion, HRDATA returned only at/after completion = 0xCAFE_0001, and no
//     STATUS sticky error set.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all register
//       accesses are raw AHB transactions to the control/status block at
//       0xF00..0xF0C. The PSEL/PENABLE/PREADY phase timing, PREADY=0 target wait
//       states, PRDATA=0xCAFE_0001 completion, source-side HRESP=0 response, and
//       HREADY_OUT completion gating are produced by the bridge FSM and the reactive
//       APB slave and observed by the monitors; this sequence only presents the
//       accepted AHB requests.
//
// CONFIDENCE: HIGH — CTRL program + single NONSEQ read at the wait-state address plus
//             a STATUS register read-back.
// =============================================================================

class ahb_mst_test_protocol_017_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_017_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL   = 32'h0000_0F00;  // CTRL (ENABLE/TIMEOUT)
  localparam logic [31:0] REG_STATUS = 32'h0000_0F04;  // STATUS (error bits)

  // ── Stimulus values ──────────────────────────────────────────────────────
  // CTRL = TIMEOUT_EN=0 | ENABLE(bit0)=1 => 0x0000_0001
  localparam logic [31:0] CTRL_NO_TIMEOUT = 32'h0000_0001;  // enabled, no timeout
  localparam logic [31:0] TEST_ADDR       = 32'h0000_4000;  // wait-state read address

  function new(string name = "ahb_mst_test_protocol_017_seq");
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
    `uvm_info("PROTO017_SEQ",
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
    `uvm_info("PROTO017_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("PROTO017_SEQ",
      "Starting TEST_PROTOCOL_017: program CTRL=0x0000_0001 (ENABLE, TIMEOUT_EN=0), present an accepted AHB read request to 0x0000_4000; the reactive APB slave holds PREADY=0 through the target wait states then completes with PREADY=1, PSLVERR=0, PRDATA=0xCAFE_0001; the bridge must keep source-side HRESP=0 stable for every wait cycle (no spurious error) and resolve to OK with HRDATA=0xCAFE_0001 only at completion; STATUS shows no sticky error",
      UVM_MEDIUM)

    // ── T0: precondition — program CTRL (ENABLE=1, TIMEOUT_EN=0) ───────────────
    do_write(REG_CTRL, CTRL_NO_TIMEOUT, "ctrl_no_timeout");

    // ── T1-T6: accepted NONSEQ READ to the wait-state address ──────────────────
    // Presenting this accepted read drives the FSM through source capture
    // (address/control latched, HRESP=0), target SETUP (PSEL=1, PENABLE=0,
    // PADDR=0x0000_4000), then target ACTIVE (PSEL=1, PENABLE=1). The reactive
    // APB slave holds PREADY=0 across the wait cycles (HREADY_OUT=0, HRESP=0
    // stable) then completes with PREADY=1, PSLVERR=0, PRDATA=0xCAFE_0001 so the
    // bridge drives HREADY_OUT=1, HRESP=0 and returns HRDATA=0xCAFE_0001.
    do_read(TEST_ADDR, "waitstate_read");

    // ── Tn: STATUS read-back (0xF04) — no sticky error bits set ────────────────
    do_read(REG_STATUS, "status_clean");

    `uvm_info("PROTO017_SEQ", "TEST_PROTOCOL_017 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_017_seq
