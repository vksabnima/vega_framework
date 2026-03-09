//----------------------------------------------------------------------
// File        : ahb_mst_cross_feature_004_seq.sv
// Description : TEST_CROSS_FEATURE_004 — burst_with_wait_states_and_timeout
//               APB slave has pready_delay=5 (set by test).
//               TIMEOUT_EN=1, TIMEOUT_VAL=1 → 2^(1+4) = 32 cycles.
//               Write 4 sequential addresses, all should complete
//               (5 < 32), read back and verify, check STATUS for no
//               timeout error.
//----------------------------------------------------------------------

class ahb_mst_cross_feature_004_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_cross_feature_004_seq)

  function new(string name = "ahb_mst_cross_feature_004_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] rdata;

    `uvm_info(get_type_name(),
      "===== TEST_CROSS_FEATURE_004: burst_with_wait_states_and_timeout =====", UVM_NONE)

    // ---- Step 1: Write CTRL: TIMEOUT_EN=1, TIMEOUT_VAL=1 (32 cycles), ENABLE=1 ----
    // Spec: bit[7]=TIMEOUT_EN, bits[6:4]=TIMEOUT_VAL, bit[0]=ENABLE
    // 0x0000_0091 → TIMEOUT_EN=1, TIMEOUT_VAL=001, ENABLE=1
    `uvm_info(get_type_name(),
      "Step 1: Write CTRL = 0x0000_0091 (TIMEOUT_EN=1, 32-cycle timeout, ENABLE=1)", UVM_MEDIUM)
    drive_reg_write(4'h0, 32'h0000_0091);

    // ---- Step 2: Write 4 sequential addresses (simulated burst) ----
    `uvm_info(get_type_name(),
      "Step 2: Write 4 sequential addresses (pready_delay=5 < timeout=32)", UVM_MEDIUM)
    drive_write(32'h0000_7000, 32'hAAAA_0000);
    drive_write(32'h0000_7004, 32'hAAAA_0001);
    drive_write(32'h0000_7008, 32'hAAAA_0002);
    drive_write(32'h0000_700C, 32'hAAAA_0003);

    // ---- Step 3: Read back all 4, verify ----
    `uvm_info(get_type_name(),
      "Step 3: Read back all 4 addresses and verify", UVM_MEDIUM)
    check_read("XFEAT_004_RB0", 32'h0000_7000, 32'hAAAA_0000);
    check_read("XFEAT_004_RB1", 32'h0000_7004, 32'hAAAA_0001);
    check_read("XFEAT_004_RB2", 32'h0000_7008, 32'hAAAA_0002);
    check_read("XFEAT_004_RB3", 32'h0000_700C, 32'hAAAA_0003);

    // ---- Step 4: Read STATUS, check no timeout error (bit[6]=0) ----
    `uvm_info(get_type_name(),
      "Step 4: Read STATUS register, verify no timeout error (bit[6]=0)", UVM_MEDIUM)
    drive_reg_read(4'h4, rdata);
    if (rdata[6] !== 1'b0) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf(
        "XFEAT_004_STATUS FAIL: STATUS[6] (TIMEOUT_ERR) = %0b, expected 0", rdata[6]))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf(
        "XFEAT_004_STATUS PASS: STATUS = 0x%08h, no timeout", rdata), UVM_LOW)
    end

    print_summary("TEST_CROSS_FEATURE_004");
  endtask
endclass
