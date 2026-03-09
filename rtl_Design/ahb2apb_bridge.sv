// =============================================================================
// AHB2APB Bridge RTL
// =============================================================================
// Spec: AHB2APB-SPEC-001 v1.0
// Author: Vikash Kumar
// Description: AHB slave to APB master protocol bridge
//   - Single clock domain (HCLK = PCLK)
//   - Burst support: SINGLE, INCR, INCR4/8/16, WRAP4/8/16
//   - Register interface: CTRL, STATUS, ERROR_ADDR, ERROR_INFO
//   - Error handling: PSLVERR propagation, address decode error, timeout
//   - Configurable timeout via CTRL.TIMEOUT_EN / CTRL.TIMEOUT_VAL
//   - Soft reset via CTRL.SOFT_RST
// =============================================================================

module ahb2apb_bridge #(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32,
    parameter APB_ADDR_START = 32'h0000_0000,
    parameter APB_ADDR_END   = 32'h0000_FFFF,
    parameter REG_BASE       = 32'h0000_0F00
)(
    // Clock & Reset
    input  logic                    HCLK,
    input  logic                    HRESETn,

    // AHB Slave Interface (Spec Table 2)
    input  logic [ADDR_WIDTH-1:0]   HADDR,
    input  logic [1:0]              HTRANS,
    input  logic                    HWRITE,
    input  logic [2:0]              HSIZE,
    input  logic [2:0]              HBURST,
    input  logic [DATA_WIDTH-1:0]   HWDATA,
    input  logic                    HSEL,
    input  logic                    HREADY_IN,
    output logic [DATA_WIDTH-1:0]   HRDATA,
    output logic                    HREADY_OUT,
    output logic                    HRESP,

    // APB Master Interface (Spec Table 4)
    output logic [ADDR_WIDTH-1:0]   PADDR,
    output logic                    PSEL,
    output logic                    PENABLE,
    output logic                    PWRITE,
    output logic [DATA_WIDTH-1:0]   PWDATA,
    input  logic [DATA_WIDTH-1:0]   PRDATA,
    input  logic                    PREADY,
    input  logic                    PSLVERR
);

    // =========================================================================
    // Local Parameters
    // =========================================================================

    // AHB Transfer Types
    localparam HTRANS_IDLE   = 2'b00;
    localparam HTRANS_BUSY   = 2'b01;
    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    // AHB Response
    localparam HRESP_OKAY  = 1'b0;
    localparam HRESP_ERROR = 1'b1;

    // FSM States
    typedef enum logic [2:0] {
        ST_IDLE      = 3'b000,
        ST_APB_SETUP = 3'b001,
        ST_APB_ACCESS= 3'b010,
        ST_REG_READ  = 3'b011,
        ST_ERROR     = 3'b100,
        ST_ERROR_2   = 3'b101
    } bridge_state_t;

    // Register Offsets from REG_BASE
    localparam REG_CTRL       = 4'h0;   // REG_BASE + 0x00
    localparam REG_STATUS     = 4'h4;   // REG_BASE + 0x04
    localparam REG_ERROR_ADDR = 4'h8;   // REG_BASE + 0x08
    localparam REG_ERROR_INFO = 4'hC;   // REG_BASE + 0x0C

    // =========================================================================
    // Internal Signals
    // =========================================================================

    bridge_state_t state, next_state;

    // Address-phase latched signals (AHB pipeline: addr in cycle N, data in cycle N+1)
    logic [ADDR_WIDTH-1:0]  haddr_lat;
    logic [1:0]             htrans_lat;
    logic                   hwrite_lat;
    logic [2:0]             hsize_lat;
    logic [2:0]             hburst_lat;
    logic                   hsel_lat;

    // Transfer pending flag
    logic                   xfer_pending;

    // Transfer valid (gated by ENABLE)
    logic                   xfer_valid;

    // Address decode
    logic                   addr_in_apb_range;
    logic                   addr_in_reg_range;
    logic                   addr_decode_error;

    // Register file
    logic [DATA_WIDTH-1:0]  reg_ctrl;
    logic [DATA_WIDTH-1:0]  reg_status;      // Assembled combinationally
    logic [DATA_WIDTH-1:0]  reg_error_addr;
    logic [DATA_WIDTH-1:0]  reg_error_info;
    logic [DATA_WIDTH-1:0]  reg_rdata;

    // CTRL field extraction (Spec Table 6)
    //   Bit[0]:    ENABLE
    //   Bit[1]:    SOFT_RST (self-clearing)
    //   Bit[3]:    ERR_INT_EN
    //   Bits[6:4]: TIMEOUT_VAL
    //   Bit[7]:    TIMEOUT_EN
    logic                   ctrl_enable;
    logic                   ctrl_soft_rst;
    logic                   ctrl_err_int_en;
    logic [2:0]             ctrl_timeout_val;
    logic                   ctrl_timeout_en;

    // Soft reset
    logic                   soft_rst_pulse;

    // Timeout
    logic [11:0]            timeout_cnt;
    logic [11:0]            timeout_limit;
    logic                   timeout_event;

    // STATUS W1C bits (stored individually)
    logic                   status_addr_err;
    logic                   status_pslverr;
    logic                   status_timeout_err;
    logic                   status_err_int;

    // Error event pulses (single-cycle)
    logic                   pslverr_event;
    logic                   addr_error_event;

    // ERPT-6: Error register lock — only first error captured until cleared
    logic                   error_captured;

    // Burst tracking
    logic [ADDR_WIDTH-1:0]  burst_addr;
    logic [4:0]             burst_count;
    logic [4:0]             burst_total;
    logic                   burst_active;

    // =========================================================================
    // Address Decode
    // =========================================================================

    assign addr_in_apb_range = (haddr_lat >= APB_ADDR_START) && (haddr_lat <= APB_ADDR_END) &&
                               !addr_in_reg_range;
    assign addr_in_reg_range = (haddr_lat >= REG_BASE) && (haddr_lat < (REG_BASE + 16));
    assign addr_decode_error = !addr_in_apb_range && !addr_in_reg_range;

    // =========================================================================
    // CTRL Register Fields (Spec Table 6)
    // =========================================================================

    assign ctrl_enable      = reg_ctrl[0];
    assign ctrl_soft_rst    = reg_ctrl[1];
    assign ctrl_err_int_en  = reg_ctrl[3];
    assign ctrl_timeout_val = reg_ctrl[6:4];
    assign ctrl_timeout_en  = reg_ctrl[7];

    // Soft reset pulse — high for one cycle when SOFT_RST is written
    assign soft_rst_pulse = ctrl_soft_rst;

    // Transfer valid — gated by ENABLE (Spec Table 6: ENABLE controls bridge)
    assign xfer_valid = xfer_pending && ctrl_enable;

    // Error event pulses
    assign pslverr_event    = (state == ST_APB_ACCESS && PREADY && PSLVERR);
    assign addr_error_event = (state == ST_IDLE && xfer_valid && addr_decode_error);

    // =========================================================================
    // Timeout Limit: 2^(TIMEOUT_VAL + 4) cycles (Spec TERR-3, Table 14)
    // =========================================================================

    always_comb begin
        case (ctrl_timeout_val)
            3'd0: timeout_limit = 12'd16;
            3'd1: timeout_limit = 12'd32;
            3'd2: timeout_limit = 12'd64;
            3'd3: timeout_limit = 12'd128;
            3'd4: timeout_limit = 12'd256;
            3'd5: timeout_limit = 12'd512;
            3'd6: timeout_limit = 12'd1024;
            3'd7: timeout_limit = 12'd2048;
            default: timeout_limit = 12'd16;
        endcase
    end

    // =========================================================================
    // STATUS Register Assembly (Spec Table 7)
    //   Bit[0]:  READY       (RO, = state==ST_IDLE)
    //   Bit[1]:  BUSY        (RO, = state!=ST_IDLE)
    //   Bit[4]:  ADDR_ERR    (R/W1C)
    //   Bit[5]:  PSLVERR     (R/W1C)
    //   Bit[6]:  TIMEOUT_ERR (R/W1C)
    //   Bit[7]:  ERR_INT     (R/W1C)
    // =========================================================================

    always_comb begin
        reg_status        = '0;
        reg_status[0]     = (state == ST_IDLE || state == ST_REG_READ);  // READY
        reg_status[1]     = (state != ST_IDLE && state != ST_REG_READ);  // BUSY
        reg_status[4]     = status_addr_err;
        reg_status[5]     = status_pslverr;
        reg_status[6]     = status_timeout_err;
        reg_status[7]     = status_err_int;
    end

    // =========================================================================
    // AHB Address Phase Latch
    // =========================================================================

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            haddr_lat   <= '0;
            htrans_lat  <= HTRANS_IDLE;
            hwrite_lat  <= 1'b0;
            hsize_lat   <= 3'b0;
            hburst_lat  <= 3'b0;
            hsel_lat    <= 1'b0;
            xfer_pending <= 1'b0;
        end else if (soft_rst_pulse) begin
            xfer_pending <= 1'b0;
        end else if (HREADY_IN && HSEL) begin
            if (HTRANS == HTRANS_NONSEQ || HTRANS == HTRANS_SEQ) begin
                haddr_lat   <= HADDR;
                htrans_lat  <= HTRANS;
                hwrite_lat  <= HWRITE;
                hsize_lat   <= HSIZE;
                hburst_lat  <= HBURST;
                hsel_lat    <= HSEL;
                xfer_pending <= 1'b1;
            end else begin
                xfer_pending <= 1'b0;
            end
        end else begin
            xfer_pending <= 1'b0;
        end
    end

    // =========================================================================
    // FSM
    // =========================================================================

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn)
            state <= ST_IDLE;
        else if (soft_rst_pulse)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                // Register accesses always work, even when ENABLE=0
                if (xfer_pending && addr_in_reg_range) begin
                    next_state = ST_REG_READ;
                end else if (xfer_valid) begin
                    if (addr_in_apb_range)
                        next_state = ST_APB_SETUP;
                    else
                        next_state = ST_ERROR;
                end
            end

            ST_APB_SETUP: begin
                next_state = ST_APB_ACCESS;
            end

            ST_APB_ACCESS: begin
                if (timeout_event)
                    next_state = ST_ERROR;
                else if (PREADY) begin
                    if (PSLVERR)
                        next_state = ST_ERROR;
                    else
                        next_state = ST_IDLE;
                end
            end

            ST_REG_READ: begin
                next_state = ST_IDLE;
            end

            ST_ERROR: begin
                // AHB two-cycle error response
                next_state = ST_ERROR_2;
            end

            ST_ERROR_2: begin
                next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    // =========================================================================
    // APB Master Outputs
    // =========================================================================

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            PADDR   <= '0;
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PWDATA  <= '0;
        end else if (soft_rst_pulse) begin
            PADDR   <= '0;
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
            PWDATA  <= '0;
        end else begin
            case (next_state)
                ST_APB_SETUP: begin
                    PADDR   <= haddr_lat;
                    PSEL    <= 1'b1;
                    PENABLE <= 1'b0;
                    PWRITE  <= hwrite_lat;
                    PWDATA  <= hwrite_lat ? HWDATA : '0;
                end

                ST_APB_ACCESS: begin
                    PENABLE <= 1'b1;
                    // PWDATA may update for writes (data phase)
                    if (hwrite_lat && state == ST_APB_SETUP)
                        PWDATA <= HWDATA;
                end

                default: begin
                    PSEL    <= 1'b0;
                    PENABLE <= 1'b0;
                end
            endcase
        end
    end

    // =========================================================================
    // AHB Slave Outputs
    // =========================================================================

    always_comb begin
        HRDATA     = '0;
        HREADY_OUT = 1'b1;
        HRESP      = HRESP_OKAY;

        case (state)
            ST_IDLE: begin
                HREADY_OUT = 1'b1;
            end

            ST_APB_SETUP: begin
                // Wait — APB setup phase
                HREADY_OUT = 1'b0;
            end

            ST_APB_ACCESS: begin
                if (PREADY) begin
                    HREADY_OUT = 1'b1;
                    HRDATA     = hwrite_lat ? '0 : PRDATA;
                    HRESP      = PSLVERR ? HRESP_ERROR : HRESP_OKAY;
                end else begin
                    HREADY_OUT = 1'b0;
                end
            end

            ST_REG_READ: begin
                HREADY_OUT = 1'b1;
                HRDATA     = reg_rdata;
            end

            ST_ERROR: begin
                // First cycle of two-cycle error response
                HREADY_OUT = 1'b0;
                HRESP      = HRESP_ERROR;
            end

            ST_ERROR_2: begin
                // Second cycle of two-cycle error response
                HREADY_OUT = 1'b1;
                HRESP      = HRESP_ERROR;
            end

            default: begin
                HREADY_OUT = 1'b1;
            end
        endcase
    end

    // =========================================================================
    // Register File
    // =========================================================================

    // Register read mux
    always_comb begin
        reg_rdata = '0;
        case (haddr_lat[3:0])
            REG_CTRL:       reg_rdata = reg_ctrl;
            REG_STATUS:     reg_rdata = reg_status;
            REG_ERROR_ADDR: reg_rdata = reg_error_addr;
            REG_ERROR_INFO: reg_rdata = reg_error_info;
            default:        reg_rdata = '0;
        endcase
    end

    // CTRL register — R/W, SOFT_RST self-clears (Spec Table 6, SRST-5)
    // Reset value: 0x0000_0071 (TIMEOUT_VAL=3'b111 at bits[6:4], ENABLE=1 at bit[0])
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            reg_ctrl <= 32'h0000_0071;
        end else if (state == ST_REG_READ && hwrite_lat && haddr_lat[3:0] == REG_CTRL) begin
            reg_ctrl <= HWDATA;
        end else begin
            reg_ctrl[1] <= 1'b0;  // SOFT_RST self-clears (SRST-5)
        end
    end

    // STATUS W1C error bits (Spec Table 7)
    logic status_w1c_wr;
    assign status_w1c_wr = (state == ST_REG_READ && hwrite_lat && haddr_lat[3:0] == REG_STATUS);

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            status_addr_err    <= 1'b0;
            status_pslverr     <= 1'b0;
            status_timeout_err <= 1'b0;
            status_err_int     <= 1'b0;
        end else if (soft_rst_pulse) begin
            // SRST-3: Soft reset clears STATUS error bits
            status_addr_err    <= 1'b0;
            status_pslverr     <= 1'b0;
            status_timeout_err <= 1'b0;
            status_err_int     <= 1'b0;
        end else begin
            // W1C: software writes 1 to clear (Spec ERCV-3, ERCV-5)
            if (status_w1c_wr && HWDATA[4]) status_addr_err    <= 1'b0;
            if (status_w1c_wr && HWDATA[5]) status_pslverr     <= 1'b0;
            if (status_w1c_wr && HWDATA[6]) status_timeout_err <= 1'b0;
            if (status_w1c_wr && HWDATA[7]) status_err_int     <= 1'b0;

            // Set on error (last assignment wins — set takes priority over clear)
            if (addr_error_event)  status_addr_err    <= 1'b1;
            if (pslverr_event)     status_pslverr     <= 1'b1;
            if (timeout_event)     status_timeout_err <= 1'b1;
            if ((addr_error_event || pslverr_event || timeout_event) && ctrl_err_int_en)
                                   status_err_int     <= 1'b1;
        end
    end

    // ERPT-6: error_captured flag — locks ERROR_ADDR/ERROR_INFO on first error until cleared
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            error_captured <= 1'b0;
        end else if (soft_rst_pulse) begin
            error_captured <= 1'b0;
        end else if (status_w1c_wr) begin
            // Clear lock when any error bit is cleared via W1C
            if (HWDATA[4] || HWDATA[5] || HWDATA[6])
                error_captured <= 1'b0;
        end else if ((pslverr_event || timeout_event || addr_error_event) && !error_captured) begin
            error_captured <= 1'b1;
        end
    end

    // ERROR_ADDR — captures address on first error only (Spec Table 8, ERPT-6)
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            reg_error_addr <= '0;
        end else if (soft_rst_pulse) begin
            reg_error_addr <= '0;
        end else if ((pslverr_event || timeout_event || addr_error_event) && !error_captured) begin
            reg_error_addr <= haddr_lat;
        end
    end

    // ERROR_INFO (Spec Table 9, Table 10, ERPT-6: first error only)
    //   [15:8]  ERR_BEAT  — beat number where error occurred
    //   [7:4]   ERR_TYPE  — 0=none, 1=addr_error, 2=timeout, 3=protocol(PSLVERR)
    //   [3]     ERR_WRITE — 1=write, 0=read
    //   [2:0]   ERR_SIZE  — transfer size
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            reg_error_info <= '0;
        end else if (soft_rst_pulse) begin
            reg_error_info <= '0;
        end else if (!error_captured) begin
            if (addr_error_event) begin
                reg_error_info <= {16'b0, 8'b0, 4'h1, hwrite_lat, hsize_lat};
            end else if (timeout_event) begin
                reg_error_info <= {16'b0, {3'b0, burst_count}, 4'h2, hwrite_lat, hsize_lat};
            end else if (pslverr_event) begin
                reg_error_info <= {16'b0, {3'b0, burst_count}, 4'h3, hwrite_lat, hsize_lat};
            end
        end
    end

    // =========================================================================
    // Timeout Counter (Spec TERR-1 through TERR-8)
    // =========================================================================

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            timeout_cnt <= '0;
        end else if (soft_rst_pulse) begin
            timeout_cnt <= '0;
        end else if (state == ST_APB_ACCESS && !PREADY && ctrl_timeout_en) begin
            timeout_cnt <= timeout_cnt + 1'b1;
        end else begin
            timeout_cnt <= '0;
        end
    end

    assign timeout_event = ctrl_timeout_en && (state == ST_APB_ACCESS) &&
                           (timeout_cnt >= timeout_limit) && !PREADY;

    // =========================================================================
    // Burst Tracking (Spec BURST-1 through BURST-6)
    // =========================================================================

    // Compute expected beat count from HBURST
    function automatic [4:0] get_burst_len(input [2:0] hburst);
        case (hburst)
            3'b000:  return 5'd1;    // SINGLE
            3'b001:  return 5'd0;    // INCR (variable, 0 = unspecified)
            3'b010:  return 5'd4;    // WRAP4
            3'b011:  return 5'd4;    // INCR4
            3'b100:  return 5'd8;    // WRAP8
            3'b101:  return 5'd8;    // INCR8
            3'b110:  return 5'd16;   // WRAP16
            3'b111:  return 5'd16;   // INCR16
            default: return 5'd1;
        endcase
    endfunction

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            burst_active <= 1'b0;
            burst_count  <= '0;
            burst_total  <= '0;
            burst_addr   <= '0;
        end else if (soft_rst_pulse) begin
            burst_active <= 1'b0;
            burst_count  <= '0;
            burst_total  <= '0;
            burst_addr   <= '0;
        end else begin
            // New transfer: NONSEQ starts a burst or single
            if (HREADY_IN && HSEL && (HTRANS == HTRANS_NONSEQ)) begin
                if (HBURST != 3'b000) begin  // Not SINGLE — start burst
                    burst_active <= 1'b1;
                    burst_count  <= 5'd0;
                    burst_total  <= get_burst_len(HBURST);
                    burst_addr   <= HADDR;
                end else begin
                    burst_active <= 1'b0;
                    burst_count  <= 5'd0;
                    burst_total  <= 5'd1;
                end
            end
            // Sequential beat in burst
            else if (HREADY_IN && HSEL && (HTRANS == HTRANS_SEQ) && burst_active) begin
                burst_count <= burst_count + 5'd1;
                burst_addr  <= HADDR;
            end
            // Burst terminated by IDLE (BURST-5)
            else if (HREADY_IN && HSEL && (HTRANS == HTRANS_IDLE)) begin
                burst_active <= 1'b0;
            end
        end
    end

endmodule
