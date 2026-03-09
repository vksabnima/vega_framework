//----------------------------------------------------------------------
// File        : ahb_mst_stress_001_seq.sv
// Description : TEST_STRESS_001 — back_to_back_stress_test
//               Write 100 sequential transfers, read back all 100
//               and verify, then final write/read verification.
//----------------------------------------------------------------------

class ahb_mst_stress_001_seq extends ahb_mst_base_seq;
  `uvm_object_utils(ahb_mst_stress_001_seq)

  function new(string name = "ahb_mst_stress_001_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [31:0] addr;
    int i;

    `uvm_info(get_type_name(),
      "===== TEST_STRESS_001: back_to_back_stress_test =====", UVM_NONE)

    // ---- Step 1: Write 100 sequential transfers ----
    `uvm_info(get_type_name(),
      "Step 1: Write 100 sequential transfers (addr=0x1000+i*4, data=i)", UVM_MEDIUM)
    for (i = 0; i < 100; i++) begin
      addr = 32'h0000_1000 + i * 4;
      drive_write(addr, i);
    end

    // ---- Step 2: Read back all 100 and verify ----
    `uvm_info(get_type_name(),
      "Step 2: Read back all 100 transfers and verify", UVM_MEDIUM)
    for (i = 0; i < 100; i++) begin
      addr = 32'h0000_1000 + i * 4;
      check_read($sformatf("STRESS_001_RB[%0d]", i), addr, i);
    end

    // ---- Step 3: Final verification — write 0xFEED_FACE to 0x9000, read back ----
    `uvm_info(get_type_name(),
      "Step 3: Final verification — write 0xFEED_FACE to 0x9000", UVM_MEDIUM)
    write_and_verify("STRESS_001_FINAL", 32'h0000_9000, 32'hFEED_FACE);

    // ---- Step 4: Coverage closure — all burst types (write + read) ----
    `uvm_info(get_type_name(),
      "Step 4: Coverage closure — exercise all burst types", UVM_MEDIUM)
    begin
      bit [31:0] rd;
      bit        rsp;
      // WRAP4 (010)
      drive_write_ex(32'h0000_A000, 32'hCC00_0001, 3'b010);
      drive_read_ex(32'h0000_A000, rd, rsp, 3'b010);
      // INCR4 (011)
      drive_write_ex(32'h0000_A010, 32'hCC00_0002, 3'b011);
      drive_read_ex(32'h0000_A010, rd, rsp, 3'b011);
      // WRAP8 (100)
      drive_write_ex(32'h0000_A020, 32'hCC00_0003, 3'b100);
      drive_read_ex(32'h0000_A020, rd, rsp, 3'b100);
      // INCR8 (101)
      drive_write_ex(32'h0000_A030, 32'hCC00_0004, 3'b101);
      drive_read_ex(32'h0000_A030, rd, rsp, 3'b101);
      // WRAP16 (110)
      drive_write_ex(32'h0000_A040, 32'hCC00_0005, 3'b110);
      drive_read_ex(32'h0000_A040, rd, rsp, 3'b110);
      // INCR16 (111)
      drive_write_ex(32'h0000_A050, 32'hCC00_0006, 3'b111);
      drive_read_ex(32'h0000_A050, rd, rsp, 3'b111);
      // INCR (001)
      drive_write_ex(32'h0000_A060, 32'hCC00_0007, 3'b001);
      drive_read_ex(32'h0000_A060, rd, rsp, 3'b001);
    end

    // ---- Step 5: Coverage closure — byte and halfword transfers ----
    `uvm_info(get_type_name(),
      "Step 5: Coverage closure — byte and halfword transfers", UVM_MEDIUM)
    begin
      bit [31:0] rd;
      bit        rsp;
      // BYTE (HSIZE=000)
      drive_write_ex(32'h0000_A100, 32'h0000_00FF, 3'b000, 3'b000);
      drive_read_ex(32'h0000_A100, rd, rsp, 3'b000, 3'b000);
      // HALFWORD (HSIZE=001)
      drive_write_ex(32'h0000_A104, 32'h0000_FFFF, 3'b000, 3'b001);
      drive_read_ex(32'h0000_A104, rd, rsp, 3'b000, 3'b001);
    end

    // ---- Step 6: Coverage closure — read errors at different ranges ----
    `uvm_info(get_type_name(),
      "Step 6: Coverage closure — read errors at different address ranges", UVM_MEDIUM)
    begin
      bit [31:0] rd;
      bit        rsp;
      // Read to JUST_ABOVE range (0x0001_xxxx)
      drive_read(32'h0001_5000, rd, rsp);
      // Read to FAR_ABOVE range (>= 0x0010_0000)
      drive_read(32'h0010_0000, rd, rsp);
    end

    print_summary("TEST_STRESS_001");
  endtask
endclass
