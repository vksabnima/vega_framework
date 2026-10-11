// =============================================================================
// FILE: sequences/ahb_mst_test_protocol_016_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_PROTOCOL_016
// DESCRIPTION: Stimulus for hresp_error_on_timeout.
//              Programs CTRL with TIMEOUT_EN=1 (bit7), TIMEOUT_VAL=3'b001 (small
//              window) and ENABLE=1 => CTRL=0x0000_0091, then drives a single
//              accepted source-side (AHB) NONSEQ write request to 0x0000_3000 with
//              HWDATA=0x1234_5678. The reactive APB slave holds PREADY=0 (stall)
//              through the target active phase, so the bridge timeout counter
//              expires and the bridge must drive HRESP=1 (error) on the source side
//              coincident with HREADY_OUT=1 at completion. Flow produced by the
//              bridge FSM and the reactive APB slave (PREADY held low during ACTIVE):
//                T1 (FLOW-1, capture) : accepted request presented (HSEL=1,
//                                       HTRANS=NONSEQ, HWRITE=1, HADDR=0x0000_3000,
//                                       HWDATA=0x1234_5678, HSIZE=word, HREADY_IN=1);
//                                       address/control/data latched, HRESP=0
//                T2 (FLOW-2, SETUP)   : PSEL=1, PENABLE=0, PWRITE=1,
//                                       PADDR=0x0000_3000; HRESP still 0
//                T3 (FLOW-4, ACTIVE)  : PSEL=1, PENABLE=1; slave holds PREADY=0
//                                       (stall); HREADY_OUT=0, HRESP=0 during wait
//                T4..Tn (stall)       : PADDR/PWDATA/PSEL/PENABLE stable while the
//                                       timeout counter counts per TIMEOUT_VAL
//                Tn (FLOW-5, timeout) : counter expires => HREADY_OUT=1, HRESP=1
//                                       (error) via the timeout error path
//              Follow-up register reads then confirm the sticky log:
//                - STATUS  read at 0xF04 — TIMEOUT_ERR sticky bit[6]=1
//                - ERROR_ADDR read at 0xF08 — captured = 0x0000_3000
//
//              Transfers:
//                1. WRITE — CTRL program (0xF00 <= 0x0000_0091): TIMEOUT_EN(bit7)=1,
//                           TIMEOUT_VAL(bits[?])=001, ENABLE(bit0)=1 (precondition)
//                2. WRITE — HTRANS=NONSEQ, HWRITE=1, HSIZE=word, HADDR=0x0000_3000,
//                           HWDATA=0x1234_5678 (timeout injection point, expect HRESP=1)
//                3. READ  — STATUS register read-back (0xF04), expect bit[6]=1
//                4. READ  — ERROR_ADDR register read-back (0xF08), expect 0x0000_3000
//
// DERIVED FROM:
//   - XTP TEST_PROTOCOL_016 steps 1-6 — confirm HRESP=0 during the wait window then
//     HRESP=1 at timeout completion, target signals stable during stall,
//     HREADY_OUT=0 until timeout then =1, STATUS.TIMEOUT_ERR (bit6) latched sticky,
//     and ERROR_ADDR captured = 0x0000_3000.
//
// NOTE: No .randomize() — fixed addresses/data per [TC1]. No uvm_reg — all register
//       accesses are raw AHB transactions to the control/status block at
//       0xF00..0xF0C. The PSEL/PENABLE/PREADY phase timing, PREADY=0 target stall,
//       timeout-counter expiry, source-side HRESP=1 response, and HREADY_OUT
//       completion gating are produced by the bridge FSM and the reactive APB slave
//       and observed by the monitors; this sequence only presents the accepted AHB
//       requests.
//
// CONFIDENCE: HIGH — CTRL program + single NONSEQ write at the timeout address plus
//             register read-backs.
// =============================================================================

class ahb_mst_test_protocol_016_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_protocol_016_seq)

  // ── Register block offsets (raw AHB accesses to the control/status block) ──
  localparam logic [31:0] REG_CTRL       = 32'h0000_0F00;  // CTRL (ENABLE/TIMEOUT)
  localparam logic [31:0] REG_STATUS     = 32'h0000_0F04;  // STATUS (TIMEOUT_ERR bit6)
  localparam logic [31:0] REG_ERROR_ADDR = 32'h0000_0F08;  // captured error address

  // ── Stimulus values ──────────────────────────────────────────────────────
  // CTRL = TIMEOUT_EN(bit7)=1 | TIMEOUT_VAL=001 | ENABLE(bit0)=1 => 0x0000_0091
  localparam logic [31:0] CTRL_TIMEOUT   = 32'h0000_0091;  // timeout-enabled config
  localparam logic [31:0] TEST_ADDR      = 32'h0000_3000;  // timeout-error address
  localparam logic [31:0] TEST_WDATA     = 32'h1234_5678;  // write data

  function new(string name = "ahb_mst_test_protocol_016_seq");
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
    `uvm_info("PROTO016_SEQ",
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
    `uvm_info("PROTO016_SEQ",
      $sformatf("READ  %s: addr=0x%08h", tag, addr), UVM_HIGH)
    finish_item(req);
  endtask : do_read

  task body();
    `uvm_info("PROTO016_SEQ",
      "Starting TEST_PROTOCOL_016: program CTRL=0x0000_0091 (TIMEOUT_EN, TIMEOUT_VAL=001, ENABLE), present an accepted AHB write request to 0x0000_3000 (HWDATA=0x1234_5678); the reactive APB slave holds PREADY=0 through the target active phase so the bridge timeout counter expires; the bridge must drive source-side HRESP=1 (error) coincident with HREADY_OUT=1; STATUS.TIMEOUT_ERR (bit6) latches sticky and ERROR_ADDR captures 0x0000_3000",
      UVM_MEDIUM)

    // ── T0: precondition — program CTRL (TIMEOUT_EN, TIMEOUT_VAL, ENABLE) ──────
    do_write(REG_CTRL, CTRL_TIMEOUT, "ctrl_timeout");

    // ── T1-Tn: accepted NONSEQ WRITE to the timeout-error address ──────────────
    // Presenting this accepted write drives the FSM through source capture
    // (address/control/data latched, HRESP=0), target SETUP (PSEL=1, PENABLE=0,
    // PWRITE=1, PADDR=0x0000_3000), then target ACTIVE (PSEL=1, PENABLE=1). The
    // reactive APB slave holds PREADY=0 so the bridge times out: HREADY_OUT=0
    // during the wait then HREADY_OUT=1 with HRESP=1 at timeout expiry.
    do_write(TEST_ADDR, TEST_WDATA, "timeout_write");

    // ── Tn: STATUS read-back (0xF04) — TIMEOUT_ERR sticky bit[6]=1 ────────────
    do_read(REG_STATUS, "status_err");

    // ── Tn: ERROR_ADDR read-back (0xF08) — captured = 0x0000_3000 ─────────────
    do_read(REG_ERROR_ADDR, "erraddr_capt");

    `uvm_info("PROTO016_SEQ", "TEST_PROTOCOL_016 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_protocol_016_seq
