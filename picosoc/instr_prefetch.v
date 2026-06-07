module instr_prefetch #(
    parameter integer DEPTH    = 4,
    parameter [31:0]  FLASH_LO = 32'h0010_0000,
    parameter [31:0]  FLASH_HI = 32'h0FFF_FFFF
)(
    input             clk,
    input             resetn,

    // Picorv32 side — wire to picorv32's mem_* outputs
    input             cpu_mem_valid,
    input             cpu_mem_instr,
    input  [31:0]     cpu_mem_addr,
    input  [31:0]     cpu_mem_wdata,
    input  [3:0]      cpu_mem_wstrb,
    output reg        cpu_mem_ready,
    output reg [31:0] cpu_mem_rdata,

    // Memory-arbiter side — wire to the existing arbiter inputs
    output reg        mem_valid,
    output reg        mem_instr,
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [3:0]  mem_wstrb,
    input             mem_ready,
    input  [31:0]     mem_rdata
);
    // FIFO storage
    reg [31:0] fifo_addr [0:DEPTH-1];
    reg [31:0] fifo_data [0:DEPTH-1];
    reg [$clog2(DEPTH+1)-1:0] count;
    reg [$clog2(DEPTH)-1:0]   head, tail;

    reg [31:0] prefetch_pc;
    reg [31:0] inflight_addr;

    // Bus state machine
    localparam S_IDLE = 2'd0, S_PREFETCH = 2'd1, S_PASS = 2'd2;
    reg [1:0] state;

    // Classify CPU request
    wire in_flash  = (cpu_mem_addr >= FLASH_LO) && (cpu_mem_addr <= FLASH_HI);
    wire cacheable = cpu_mem_valid && cpu_mem_instr && in_flash && (cpu_mem_wstrb == 4'b0);
    wire fifo_hit  = (count > 0) && (fifo_addr[head] == cpu_mem_addr);

    wire consume = cacheable && fifo_hit && !cpu_mem_ready;
    wire fill    = (state == S_PREFETCH) && mem_ready;

    always @(posedge clk) begin
        if (!resetn) begin
            count <= 0;
            head  <= 0;
            tail  <= 0;
            state <= S_IDLE;
            mem_valid     <= 0;
            cpu_mem_ready <= 0;
            prefetch_pc   <= FLASH_LO;
        end else begin
            // Default deassert
            cpu_mem_ready <= 0;

            // ---- FIFO consume (hit served to CPU) ----
            if (consume) begin
                cpu_mem_rdata <= fifo_data[head];
                cpu_mem_ready <= 1;
                head <= head + 1;
            end

            // ---- FIFO fill (prefetch returned) ----
            if (fill) begin
                fifo_addr[tail] <= inflight_addr;
                fifo_data[tail] <= mem_rdata;
                tail <= tail + 1;
                prefetch_pc <= inflight_addr + 4;
            end

            // Net count update (both can happen the same cycle)
            if (consume && !fill) count <= count - 1;
            else if (!consume && fill) count <= count + 1;

            // ---- Branch detection: cacheable request misses FIFO -> flush ----
            if (cacheable && !fifo_hit && state == S_IDLE) begin
                count <= 0;
                head  <= 0;
                tail  <= 0;
                prefetch_pc <= cpu_mem_addr;
            end

            // ---- Bus state machine ----
            case (state)
            S_IDLE: begin
                // Priority 1: uncacheable CPU access (data or non-flash) -> pass through
                if (cpu_mem_valid && !cacheable) begin
                    mem_valid <= 1;
                    mem_instr <= cpu_mem_instr;
                    mem_addr  <= cpu_mem_addr;
                    mem_wdata <= cpu_mem_wdata;
                    mem_wstrb <= cpu_mem_wstrb;
                    state     <= S_PASS;
                end
                // Priority 2: cacheable miss -> fetch this address first
                else if (cacheable && !fifo_hit) begin
                    mem_valid     <= 1;
                    mem_instr     <= 1;
                    mem_addr      <= cpu_mem_addr;
                    mem_wstrb     <= 0;
                    inflight_addr <= cpu_mem_addr;
                    state         <= S_PREFETCH;
                end
                // Priority 3: opportunistic prefetch (FIFO has room)
                else if (count < DEPTH) begin
                    mem_valid     <= 1;
                    mem_instr     <= 1;
                    mem_addr      <= prefetch_pc;
                    mem_wstrb     <= 0;
                    inflight_addr <= prefetch_pc;
                    state         <= S_PREFETCH;
                end
            end

            S_PREFETCH: begin
                if (mem_ready) begin
                    mem_valid <= 0;
                    state     <= S_IDLE;
                end
            end

            S_PASS: begin
                if (mem_ready) begin
                    cpu_mem_rdata <= mem_rdata;
                    cpu_mem_ready <= 1;
                    mem_valid     <= 0;
                    state         <= S_IDLE;
                end
            end
            endcase
        end
    end
endmodule