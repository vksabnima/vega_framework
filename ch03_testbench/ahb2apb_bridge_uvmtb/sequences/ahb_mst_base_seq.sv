// =============================================================================
// File        : ahb_mst_base_seq.sv
// Description : Base sequence with reusable helper tasks
//
// All XTP-derived test sequences extend this class.  Provides:
//   - drive_write(addr, data)            — single AHB write transaction
//   - drive_read(addr, rdata, resp)      — single AHB read transaction
//   - check_read(tag, addr, expected)    — read + compare with expected
//   - write_and_verify(tag, addr, data)  — write + readback + compare
//   - pass_count / fail_count            — self-checking counters
//   - print_summary()                    — print PASS/FAIL totals
//
// Uses $urandom-free directed stimulus.  No .randomize() per [TC1].
// =============================================================================

class ahb_mst_base_seq extends uvm_sequence #(ahb_mst_seq_item);
  `uvm_object_utils(ahb_mst_base_seq)

  int pass_count = 0;
  int fail_count = 0;

  function new(string name = "ahb_mst_base_seq");
    super.new(name);
  endfunction

  // =========================================================================
  // drive_write — drive a single AHB write and wait for completion
  // =========================================================================
  task drive_write(bit [31:0] addr, bit [31:0] data);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create("req");
    req.HADDR  = addr;
    req.HWRITE = 1'b1;
    req.HWDATA = data;
    req.post_randomize();
    start_item(req);
    finish_item(req);
    `uvm_info(get_type_name(), $sformatf("WRITE 0x%08h -> [0x%08h] HRESP=%0b",
              data, addr, req.HRESP), UVM_MEDIUM)
  endtask

  // =========================================================================
  // drive_write_ex — write with explicit HBURST and HSIZE (set AFTER
  // post_randomize so they are not overwritten)
  // =========================================================================
  task drive_write_ex(bit [31:0] addr, bit [31:0] data,
                      bit [2:0] hburst, bit [2:0] hsize = 3'b010);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create("req");
    req.HADDR  = addr;
    req.HWRITE = 1'b1;
    req.HWDATA = data;
    req.post_randomize();
    req.HBURST = hburst;
    req.HSIZE  = hsize;
    start_item(req);
    finish_item(req);
    `uvm_info(get_type_name(), $sformatf("WRITE_EX 0x%08h -> [0x%08h] HBURST=%03b HSIZE=%03b HRESP=%0b",
              data, addr, hburst, hsize, req.HRESP), UVM_MEDIUM)
  endtask

  // =========================================================================
  // drive_read — drive a single AHB read and return captured data
  // =========================================================================
  task drive_read(bit [31:0] addr, output bit [31:0] rdata, output bit resp);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create("req");
    req.HADDR  = addr;
    req.HWRITE = 1'b0;
    req.HWDATA = 32'h0;
    req.post_randomize();
    start_item(req);
    finish_item(req);
    rdata = req.HRDATA;
    resp  = req.HRESP;
    `uvm_info(get_type_name(), $sformatf("READ  [0x%08h] -> 0x%08h HRESP=%0b",
              addr, rdata, resp), UVM_MEDIUM)
  endtask

  // =========================================================================
  // drive_read_ex — read with explicit HBURST and HSIZE
  // =========================================================================
  task drive_read_ex(bit [31:0] addr, output bit [31:0] rdata, output bit resp,
                     input bit [2:0] hburst, input bit [2:0] hsize = 3'b010);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create("req");
    req.HADDR  = addr;
    req.HWRITE = 1'b0;
    req.HWDATA = 32'h0;
    req.post_randomize();
    req.HBURST = hburst;
    req.HSIZE  = hsize;
    start_item(req);
    finish_item(req);
    rdata = req.HRDATA;
    resp  = req.HRESP;
    `uvm_info(get_type_name(), $sformatf("READ_EX  [0x%08h] -> 0x%08h HBURST=%03b HSIZE=%03b HRESP=%0b",
              addr, rdata, hsize, hburst, resp), UVM_MEDIUM)
  endtask

  // =========================================================================
  // check_read — read from addr and compare against expected value
  // =========================================================================
  task check_read(string tag, bit [31:0] addr, bit [31:0] expected);
    bit [31:0] rdata;
    bit resp;
    drive_read(addr, rdata, resp);
    if (rdata !== expected) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf("%s FAIL: [0x%08h] expected 0x%08h, got 0x%08h",
                 tag, addr, expected, rdata))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf("%s PASS: [0x%08h] = 0x%08h",
                tag, addr, rdata), UVM_LOW)
    end
  endtask

  // =========================================================================
  // write_and_verify — write data, then readback and compare
  // =========================================================================
  task write_and_verify(string tag, bit [31:0] addr, bit [31:0] data);
    drive_write(addr, data);
    check_read(tag, addr, data);
  endtask

  // =========================================================================
  // drive_write_get_resp — write and return HRESP for error checking
  // =========================================================================
  task drive_write_get_resp(bit [31:0] addr, bit [31:0] data,
                            output bit [31:0] rdata, output bit resp);
    ahb_mst_seq_item req;
    req = ahb_mst_seq_item::type_id::create("req");
    req.HADDR  = addr;
    req.HWRITE = 1'b1;
    req.HWDATA = data;
    req.post_randomize();
    start_item(req);
    finish_item(req);
    rdata = req.HRDATA;
    resp  = req.HRESP;
    `uvm_info(get_type_name(), $sformatf("WRITE 0x%08h -> [0x%08h] HRESP=%0b",
              data, addr, resp), UVM_MEDIUM)
  endtask

  // =========================================================================
  // check_resp — verify HRESP matches expected value
  // =========================================================================
  task check_resp(string tag, bit resp, bit expected);
    if (resp !== expected) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf("%s FAIL: HRESP=%0b expected %0b",
                 tag, resp, expected))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf("%s PASS: HRESP=%0b",
                tag, resp), UVM_LOW)
    end
  endtask

  // =========================================================================
  // drive_reg_write — write to bridge register (REG_BASE + offset)
  // =========================================================================
  task drive_reg_write(bit [3:0] reg_offset, bit [31:0] data);
    bit [31:0] addr;
    addr = 32'h0000_0F00 + {28'h0, reg_offset};
    drive_write(addr, data);
  endtask

  // =========================================================================
  // drive_reg_read — read from bridge register (REG_BASE + offset)
  // =========================================================================
  task drive_reg_read(bit [3:0] reg_offset, output bit [31:0] rdata);
    bit [31:0] addr;
    bit resp;
    addr = 32'h0000_0F00 + {28'h0, reg_offset};
    drive_read(addr, rdata, resp);
  endtask

  // =========================================================================
  // check_reg_read — read register and compare against expected value
  // =========================================================================
  task check_reg_read(string tag, bit [3:0] reg_offset, bit [31:0] expected);
    bit [31:0] rdata;
    drive_reg_read(reg_offset, rdata);
    if (rdata !== expected) begin
      fail_count++;
      `uvm_error(get_type_name(), $sformatf("%s FAIL: REG[0x%01h] expected 0x%08h, got 0x%08h",
                 tag, reg_offset, expected, rdata))
    end else begin
      pass_count++;
      `uvm_info(get_type_name(), $sformatf("%s PASS: REG[0x%01h] = 0x%08h",
                tag, reg_offset, rdata), UVM_LOW)
    end
  endtask

  // =========================================================================
  // print_summary — call at end of body()
  // =========================================================================
  function void print_summary(string test_id);
    `uvm_info(get_type_name(), $sformatf("%s SUMMARY: %0d PASS, %0d FAIL",
              test_id, pass_count, fail_count), UVM_NONE)
  endfunction

endclass
