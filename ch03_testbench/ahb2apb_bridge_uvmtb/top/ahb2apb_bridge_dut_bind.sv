// ahb2apb_bridge_dut_bind.sv
// Generated from RTL port list by vega_llm_tbgen.py v2.0
// RTL module: ahb2apb_bridge
// Cross-check: MISMATCHES — see warnings above

// EDIT_REQUIRED: connect every port to the appropriate interface signal

ahb2apb_bridge #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .APB_ADDR_START(32'h0000_0000),
    .APB_ADDR_END(32'h0000_FFFF)
) dut (
    .HCLK                (),
    .HRESETn             (),
    .HTRANS              (),
    .HWRITE              (),
    .HSIZE               (),
    .HBURST              (),
    .HSEL                (),
    .HREADY_IN           (),
    .HREADY_OUT          (),
    .HRESP               (),
    .PSEL                (),
    .PENABLE             (),
    .PWRITE              (),
    .PREADY              (),
    .PSLVERR             ()
);