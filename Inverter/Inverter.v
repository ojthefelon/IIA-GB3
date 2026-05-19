module top (
    input CLK,
    output LED1,
);
    reg A = 0;
    assign LED1 = A;
    reg [23:0] clkdiv = 0;

    always @(posedge CLK) begin
        if (clkdiv == 1200000) begin
            A<=!A;
            clkdiv<=0;
        end else begin
            clkdiv<=clkdiv+1;
        end
    end
endmodule 