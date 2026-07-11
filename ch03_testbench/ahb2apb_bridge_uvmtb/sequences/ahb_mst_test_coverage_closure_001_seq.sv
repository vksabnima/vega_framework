// =============================================================================
// FILE: sequences/ahb_mst_test_coverage_closure_001_seq.sv
// =============================================================================
// COMPONENT  : AHB Master Sequence — TEST_COVERAGE_CLOSURE_001
// DESCRIPTION: Directed stimulus that closes the functional-coverage bins the
//              feature regression leaves open.  After the rest of the suite the
//              measured union sat at 76.6% (98/128); every open bin was a
//              reachable AHB_TXN stimulus hole, not an architectural exclusion.
//              This sequence drives exactly those holes:
//
//                * Every HBURST encoding the suite never produced —
//                    INCR, WRAP4, WRAP8, INCR8, WRAP16, INCR16 —
//                  each as one WRITE and one READ to a forwardable APB
//                  address (closes hburst.*, burst_x_write.*, burst_x_resp.*).
//                  These are single forwarded transfers carrying each HBURST
//                  code; an AHB-to-APB bridge forwards every beat independently,
//                  so a one-beat transfer is sufficient to exercise the encoding.
//                * One BYTE-size transfer            -> hsize.BYTE
//                * One READ into the APB_HIGH window -> addr_x_write.APB_HIGH.READ
//                * A WRITE to a MID_RANGE error addr -> ERR.addr.MID_RANGE,
//                                                       dir_x_addr.WRITE.MID_RANGE
//                * A READ to a JUST_ABOVE error addr -> dir_x_addr.READ.JUST_ABOVE
//                * A READ to a MID_RANGE error addr  -> dir_x_addr.READ.MID_RANGE
//
//              Forwardable transfers use addresses in 0x0..0xEFFF (outside the
//              0xF00..0xF0F register window) so the scoreboard checks the
//              HADDR->PADDR / data forwarding (VG1-VG4).  Error transfers use
//              out-of-range addresses (>= 0x1_0000); the bridge answers HRESP=
//              ERROR and the scoreboard correctly does not expect an APB beat.
//
// DERIVED FROM:
//   - Coverage gap analysis of the full regression (coverage_report_measured).
//
// NOTE: No .randomize() — fixed addresses/data per [TC1].  Does NOT call
//       req.post_randomize() (it would reset HBURST/HSIZE to SINGLE/WORD).
//
// CONFIDENCE: HIGH — directed single transfers, encodings driven explicitly.
// =============================================================================

class ahb_mst_test_coverage_closure_001_seq extends uvm_sequence #(ahb_mst_seq_item);

  `uvm_object_utils(ahb_mst_test_coverage_closure_001_seq)

  function new(string name = "ahb_mst_test_coverage_closure_001_seq");
    super.new(name);
  endfunction : new

  // One directed transfer.
  task do_xfer(string tag, logic [31:0] addr, bit is_write,
               logic [2:0] burst, logic [2:0] size, logic [31:0] wdata);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create(tag);
    start_item(req);
    req.addr       = addr;
    req.write      = is_write;
    req.wdata      = is_write ? wdata : 32'h0;
    req.trans_type = 2'b10;          // NONSEQ — independent single transfer
    req.burst      = burst;
    req.size       = size;
    // NOTE: no req.post_randomize() — it would force burst/size back to
    // SINGLE/WORD and defeat the whole point of this sequence.
    `uvm_info("COVCLOSE_SEQ",
      $sformatf("%s: HADDR=0x%08h %s HBURST=0b%03b HSIZE=0b%03b",
                tag, addr, is_write ? "WR" : "RD", burst, size), UVM_HIGH)
    finish_item(req);
  endtask

  task body();
    // --- Burst-encoding sweep: each as WRITE then READ, forwardable addrs ---
    // {INCR, WRAP4, WRAP8, INCR8, WRAP16, INCR16}.  INCR4 + SINGLE are already
    // covered by the datapath/connectivity tests.
    logic [2:0] burst_codes [6] = '{3'b001, 3'b010, 3'b100, 3'b101, 3'b110, 3'b111};
    string      burst_names [6] = '{"INCR","WRAP4","WRAP8","INCR8","WRAP16","INCR16"};
    logic [31:0] wr_base = 32'h0000_1000;
    int i;

    `uvm_info("COVCLOSE_SEQ", "Starting TEST_COVERAGE_CLOSURE_001 directed stimulus", UVM_MEDIUM)

    for (i = 0; i < 6; i++) begin
      // WRITE then READ for this burst code (covers burst_x_write .WRITE/.READ
      // and burst_x_resp.<code>.OKAY).  Read of INCR targets the APB_HIGH
      // window to also close addr_x_write.APB_HIGH.READ.
      logic [31:0] wa = wr_base + (i << 4);          // 0x1000, 0x1010, ...
      logic [31:0] ra = (i == 0) ? 32'h0000_8000     // APB_HIGH read
                                 : (wr_base + (i << 4) + 32'h4);
      do_xfer($sformatf("covclose_%s_wr", burst_names[i]), wa, 1'b1,
              burst_codes[i], 3'b010, 32'hC0DE_0000 + i);
      do_xfer($sformatf("covclose_%s_rd", burst_names[i]), ra, 1'b0,
              burst_codes[i], 3'b010, 32'h0);
    end

    // --- BYTE-size transfer (hsize.BYTE) ---
    do_xfer("covclose_byte_wr", 32'h0000_1060, 1'b1, 3'b000, 3'b000, 32'h0000_00A5);

    // --- Error scenarios: out-of-range addresses -> HRESP=ERROR ---
    // WRITE to MID_RANGE  -> ERR.addr.MID_RANGE + dir_x_addr.WRITE.MID_RANGE
    do_xfer("covclose_err_wr_mid",  32'h0005_0000, 1'b1, 3'b000, 3'b010, 32'hDEAD_BEEF);
    // READ  to JUST_ABOVE -> dir_x_addr.READ.JUST_ABOVE
    do_xfer("covclose_err_rd_just", 32'h0001_0000, 1'b0, 3'b000, 3'b010, 32'h0);
    // READ  to MID_RANGE  -> dir_x_addr.READ.MID_RANGE
    do_xfer("covclose_err_rd_mid",  32'h0005_0000, 1'b0, 3'b000, 3'b010, 32'h0);

    `uvm_info("COVCLOSE_SEQ", "TEST_COVERAGE_CLOSURE_001 stimulus complete", UVM_MEDIUM)
  endtask : body

endclass : ahb_mst_test_coverage_closure_001_seq
