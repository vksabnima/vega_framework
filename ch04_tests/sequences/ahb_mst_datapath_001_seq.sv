// =============================================================================
// File        : ahb_mst_datapath_001_seq.sv
// Description : TEST_MAIN_DATAPATH_001 — Single write conversion
//
// XTP Reference:
//   test_id  : TEST_MAIN_DATAPATH_001
//   name     : single_write_conversion
//   req_ref  : REQ_003 (Single Transfer Conversion)
//   objective: Verify single AHB write converts to single APB write
//
// Steps (from XTP):
//   1. Drive HTRANS=NONSEQ, HADDR=0x0000_1000, HWRITE=1, HSIZE=WORD,
//      HSEL=1, HREADY_IN=1
//   2. Drive HWDATA=0xDEAD_BEEF, observe APB SETUP phase:
//      PSEL=1, PENABLE=0, PADDR=0x0000_1000, PWRITE=1, PWDATA=0xDEAD_BEEF
//   3. Observe APB ACCESS phase: PSEL=1, PENABLE=1
//   4. Drive PREADY=1 → APB transfer completes, HREADY_OUT=1
//   5. Observe APB IDLE: PSEL=0, PENABLE=0
//   6. Read back: HADDR=0x0000_1000, HWRITE=0
//   7. Sample PRDATA when PREADY=1 → PRDATA=0xDEAD_BEEF
//
// Pass criteria:
//   1. Single AHB beat converts to single APB transfer
//   2. Address and data forwarded correctly
//   3. Read-back confirms write
//
// Verification goals exercised: VG1, VG2, VG3, VG4, VG6
// =============================================================================

class ahb_mst_datapath_001_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_datapath_001_seq)

  function new(string name = "ahb_mst_datapath_001_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info(get_type_name(),
      "===== TEST_MAIN_DATAPATH_001: Single write conversion =====", UVM_NONE)

    // Step 1-5: Write 0xDEAD_BEEF to 0x0000_1000
    //   Address forwarding (VG1) and write data integrity (VG2) are
    //   verified by the scoreboard comparing AHB and APB transactions.
    //   Direction preservation (VG4) is also checked.
    // Step 6-7: Read back from same address
    //   Read data integrity (VG3) verified by scoreboard.
    //   Sequence self-check verifies write persistence.
    write_and_verify("DATAPATH_001", 32'h0000_1000, 32'hDEAD_BEEF);

    print_summary("TEST_MAIN_DATAPATH_001");
  endtask

endclass
