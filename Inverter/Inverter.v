module inverter (
    input CLK,
    output LED1,
)
    reg A = 0;
    assign LED1 = A;

    always @(posedge CLK) begin
        if (clkdiv == 1200000) begin
            A<=!A;
        end
    end
endmodule 