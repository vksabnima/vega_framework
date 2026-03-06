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

    // Address decode
    logic                   addr_in_apb_range;
    logic                   addr_in_reg_range;
    logic                   addr_decode_error;

    // Register file
    logic [DATA_WIDTH-1:0]  reg_ctrl;
    logic [DATA_WIDTH-1:0]  reg_status;
    logic [DATA_WIDTH-1:0]  reg_error_addr;
    logic [DATA_WIDTH-1:0]  reg_error_info;
    logic [DATA_WIDTH-1:0]  reg_rdata;

    // Timeout counter
    logic [15:0]            timeout_cnt;
    logic                   timeout_en;
    logic [15:0]            timeout_val;
    logic                   timeout_event;

    // Error tracking
    logic                   apb_error;
    logic                   addr_error;

    // Burst tracking
    logic [ADDR_WIDTH-1:0]  burst_addr;
    logic [3:0]             burst_count;
    logic                   burst_active;

    // =========================================================================
    // Address Decode
    // =========================================================================

    assign addr_in_apb_range = (haddr_lat >= APB_ADDR_START) && (haddr_lat <= APB_ADDR_END) &&
                               !addr_in_reg_range;
    assign addr_in_reg_range = (haddr_lat >= REG_BASE) && (haddr_lat < (REG_BASE + 16));
    assign addr_decode_error = !addr_in_apb_range && !addr_in_reg_range;

    // =========================================================================
    // CTRL Register Fields
    // =========================================================================

    assign timeout_en  = reg_ctrl[0];
    assign timeout_val = reg_ctrl[31:16];

    // =========================================================================
    // AHB Address Phase Latch
    // =========================================================================
    // Latch address-phase signals when a valid transfer is presented
    // AHB pipeline: we capture addr in cycle N, use HWDATA in cycle N+1

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            haddr_lat   <= '0;
            htrans_lat  <= HTRANS_IDLE;
            hwrite_lat  <= 1'b0;
            hsize_lat   <= 3'b0;
            hburst_lat  <= 3'b0;
            hsel_lat    <= 1'b0;
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
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (xfer_pending) begin
                    if (addr_in_reg_range)
                        next_state = ST_REG_READ;
                    else if (addr_in_apb_range)
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

    // CTRL register — R/W
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            reg_ctrl <= 32'h0000_0100;  // Default: timeout disabled, timeout_val=256
        end else if (state == ST_REG_READ && hwrite_lat && haddr_lat[3:0] == REG_CTRL) begin
            reg_ctrl <= HWDATA;
        end
    end

    // STATUS register — RO, bit[0]=busy, bit[1]=error, bit[2]=timeout
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            reg_status <= '0;
        end else begin
            reg_status[0] <= (state != ST_IDLE);                          // busy
            reg_status[1] <= apb_error || addr_error;                     // error
            reg_status[2] <= timeout_event;                               // timeout
            reg_status[31:3] <= '0;
        end
    end

    // ERROR_ADDR — captures address on error
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            reg_error_addr <= '0;
        end else if ((state == ST_APB_ACCESS && PREADY && PSLVERR) ||
                     timeout_event ||
                     (state == ST_IDLE && xfer_pending && addr_decode_error)) begin
            reg_error_addr <= haddr_lat;
        end
    end

    // ERROR_INFO — bit[0]=PSLVERR, bit[1]=addr_decode, bit[2]=timeout, bit[3]=write
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            reg_error_info <= '0;
        end else if (state == ST_APB_ACCESS && PREADY && PSLVERR) begin
            reg_error_info <= {28'b0, hwrite_lat, 1'b0, 1'b0, 1'b1};     // PSLVERR
        end else if (state == ST_IDLE && xfer_pending && addr_decode_error) begin
            reg_error_info <= {28'b0, hwrite_lat, 1'b0, 1'b1, 1'b0};     // addr decode
        end else if (timeout_event) begin
            reg_error_info <= {28'b0, hwrite_lat, 1'b1, 1'b0, 1'b0};     // timeout
        end
    end

    // Error flags
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            apb_error  <= 1'b0;
            addr_error <= 1'b0;
        end else begin
            if (state == ST_APB_ACCESS && PREADY && PSLVERR)
                apb_error <= 1'b1;
            else if (state == ST_IDLE)
                apb_error <= 1'b0;

            if (state == ST_IDLE && xfer_pending && addr_decode_error)
                addr_error <= 1'b1;
            else if (state == ST_IDLE && !xfer_pending)
                addr_error <= 1'b0;
        end
    end

    // =========================================================================
    // Timeout Counter
    // =========================================================================

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            timeout_cnt <= '0;
        end else if (state == ST_APB_ACCESS && !PREADY && timeout_en) begin
            timeout_cnt <= timeout_cnt + 1'b1;
        end else begin
            timeout_cnt <= '0;
        end
    end

    assign timeout_event = timeout_en && (state == ST_APB_ACCESS) && (timeout_cnt >= timeout_val) && !PREADY;

endmodule
