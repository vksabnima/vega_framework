// =============================================================================
// File        : reset_ctrl_if.sv
// Description : Reset control interface for UVM tests
//
// Provides a mechanism for UVM tests to toggle HRESETn during simulation.
// Connected to tb_top's reset network via continuous assignment.
// =============================================================================

interface reset_ctrl_if (input logic HCLK);

  logic reset_n = 1'b1;  // Default: reset deasserted

  // Assert reset for a given number of clock cycles
  task assert_reset(int hold_cycles);
    @(posedge HCLK);
    reset_n = 1'b0;
    repeat(hold_cycles) @(posedge HCLK);
    reset_n = 1'b1;
  endtask

endinterface
