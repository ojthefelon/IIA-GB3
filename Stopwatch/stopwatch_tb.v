// Commands to run iverilog are as follows:
// iverilog -g2012 -o stopwatch_tb stopwatch.v stopwatch_tb.v
// vvp stopwatch_tb



`default_nettype none
`timescale 1ns/1ps
module stopwatch_tb;
	reg CLK = 0;
	reg BTN_N = 1, BTN1 = 0, BTN2 = 0, BTN3 = 0;
	wire LED1, LED2, LED3, LED4, LED5;
	wire P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10;

	//instantiate the design under test (DUT) with a smaller clock divider for faster simulation
	top #(.CLKDIV_MAX(99)) dut (
		.CLK(CLK),
		.BTN_N(BTN_N), .BTN1(BTN1), .BTN2(BTN2), .BTN3(BTN3),
		.LED1(LED1), .LED2(LED2), .LED3(LED3), .LED4(LED4), .LED5(LED5),
		.P1A1(P1A1), .P1A2(P1A2), .P1A3(P1A3), .P1A4(P1A4),
		.P1A7(P1A7), .P1A8(P1A8), .P1A9(P1A9), .P1A10(P1A10)
	);

	always #5 CLK = ~CLK; //sets a clock of 100MHz (which's greater than icebreaker clock of 12MHz, but we only care about the number of edges)
	integer errors = 0;


	//to make debugging easier, display the state after each state
	`define CHECK(cond, name) \
		if (!(cond)) begin \
			$display("FAILED: %s", name); \
			errors = errors + 1; \
		end else begin \
			$display("PASSED: %s", name); \
		end

	//actual test sequence in an initial block
	initial begin
		//the following initially seeds dout so that at t=0, it has the correct valu needed
		//this would be equivalent to replacing the always block in display_value_incrementer with 
		//an assign statement of assign dout = din + 1; instead of using a register and clock edge to update it
		dut.display_value_incrementer.dout = 8'h01;

		//reset the stopwatch
		BTN_N = 0; #10; BTN_N = 1; #10;
		`CHECK(dut.display_value === 8'h00, "power-on: display == 00");
		//start the stopwatch
		BTN3 = 1; #10; BTN3 = 0; #1000;
		`CHECK(dut.running === 1'b1, "start: stopwatch running");
		//lap the stopwatch
		BTN2 = 1; #10; BTN2 = 0; #1000;
		`CHECK(dut.lap_value === 8'h01, "lap: lap value == 01");
		//stop the stopwatch
		BTN1 = 1; #10; BTN1 = 0; #1000;
		`CHECK(dut.running === 1'b0, "stop: stopwatch not running");
		//reset the stopwatch again
		BTN_N = 0; #10; BTN_N = 1; #10;
		`CHECK(dut.display_value === 8'h00, "reset: display == 00");

		if (errors == 0) 
			$display("RESULT: ALL PASS");
        else             
			$display("RESULT: %0d FAILS", errors);


		$finish;
	 end

endmodule


