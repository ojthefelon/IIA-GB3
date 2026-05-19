// Cause yosys to throw an error when we implicitly declare nets
`default_nettype none

// Project entry point
module top#(parameter CLKDIV_MAX = 12000000)(//parameter that can be overridden at compile time to adjust the clock divider for different clock frequencies
	input  CLK,
	input  BTN_N, BTN1, BTN2, BTN3,
	output LED1, LED2, LED3, LED4, LED5,
	//output LED1,
	output P1A1, P1A2, P1A3, P1A4, P1A7, P1A8, P1A9, P1A10
);
	// 7 segment control line bus
	wire [7:0] seven_segment;
	reg led_1hz = 0;
	reg half_second = 0;

	// Assign 7 segment control line bus to Pmod pins
	assign { P1A10, P1A9, P1A8, P1A7, P1A4, P1A3, P1A2, P1A1 } = seven_segment;
	assign LED1 = led_1hz;
	assign LED2 = 0;
	assign LED3 = 0;
	assign LED4 = 0;
	assign LED5 = 0;

	// Display value register and increment bus
	reg [7:0] display_value = 0;
	wire [7:0] display_value_inc;

	// Clock divider and pulse registers
	reg [23:0] clkdiv = 0;
	reg clkdiv_pulse = 0;

	// Combinatorial logic
	//assign LED1 = BTN1 && BTN2;                           
	//assign LED2 = BTN1 && BTN3;                     
	//assign LED3 = BTN2 && BTN3;                      
	//assign LED4 = !BTN_N;                  // BTN_N is active low
	//assign LED5 = BTN1 || BTN2 || BTN3 || !BTN_N; 

	// 1Hz flashing LED

	//Adding reset, start/stop and lap functionality
	reg running = 0;
	reg [7:0] lap_value = 0;
	reg [4:0] lap_timeout = 0;

	// Synchronous logic
	always @(posedge CLK) begin
		if (!BTN_N) begin
			clkdiv <= 0;
			clkdiv_pulse <= 0;
			led_1hz <= 0;
			half_second <= 0;

			running <= 0;
			display_value <= 0;
			lap_timeout <= 0;

		end else begin
			clkdiv_pulse <= 0;
			if (clkdiv == (CLKDIV_MAX/2 - 1)) begin
				clkdiv <= 0;
				led_1hz <= ~led_1hz;
				half_second <= ~half_second;

				if (half_second)
					clkdiv_pulse <= 1;
			end else begin
				clkdiv <= clkdiv + 1;
			end
		
		// Clock divider pulse generator
		//if (clkdiv == CLKDIV_MAX) begin
		//	clkdiv <= 0;
		//	clkdiv_pulse <= 1;
		//end else begin
		//	clkdiv <= clkdiv + 1;
		//	clkdiv_pulse <= 0;
		//end

			// Timer and lap coutndown
			if (clkdiv_pulse) begin
				if (running)
					display_value <= display_value_inc;
				if (lap_timeout != 0)
					lap_timeout <= lap_timeout - 1;
			end
	//
	//		//START/STOP button
			if (BTN3)
				running <= 1;
			if (BTN1)
				running <= 0;
	//
	//		//LAP
			if (BTN2) begin
				lap_value <= display_value;
				lap_timeout <=20;
			end
	//
			//RESET
	//		if (!BTN_N) begin
	//			running <= 0;
	//			display_value <= 0;
	//			lap_timeout <= 0;
	//		end
		end

	end

	bcd8_increment display_value_incrementer (
		.din(display_value),
		.dout(display_value_inc)
	);

	// 7 segment display control Pmod 1A
	seven_seg_ctrl seven_segment_ctrl (
		.CLK(CLK),
		.din(lap_timeout ? lap_value : display_value),
		.dout(seven_segment)
	);

endmodule

// BCD (Binary Coded Decimal) counter
module bcd8_increment (
	input [7:0] din,
	output reg [7:0] dout
);
	always @* begin
		case (1'b1)
			din[7:0] == 8'h 99:
				dout = 0;
			din[3:0] == 4'h 9:
				dout = {din[7:4] + 4'd 1, 4'h 0};
			default:
				dout = {din[7:4], din[3:0] + 4'd 1};
		endcase
	end
endmodule

// Seven segment controller
// Switches quickly between the two parts of the display
// to create the illusion of both halves being illuminated
// at the same time.
module seven_seg_ctrl (
	input CLK,
	input [7:0] din,
	output reg [7:0] dout
);
	wire [6:0] lsb_digit;
	wire [6:0] msb_digit;

	seven_seg_hex msb_nibble (
		.din(din[7:4]),
		.dout(msb_digit)
	);

	seven_seg_hex lsb_nibble (
		.din(din[3:0]),
		.dout(lsb_digit)
	);

	reg [9:0] clkdiv = 0;
	reg clkdiv_pulse = 0;
	reg msb_not_lsb = 0;

	always @(posedge CLK) begin
		clkdiv <= clkdiv + 1;
		clkdiv_pulse <= &clkdiv;
		msb_not_lsb <= msb_not_lsb ^ clkdiv_pulse;

		if (clkdiv_pulse) begin
			if (msb_not_lsb) begin
				dout[6:0] <= ~msb_digit;
				dout[7] <= 0;
			end else begin
				dout[6:0] <= ~lsb_digit;
				dout[7] <= 1;
			end
		end
	end
endmodule

// Convert 4bit numbers to 7 segments
module seven_seg_hex (
	input [3:0] din,
	output reg [6:0] dout
);
	always @*
		case (din)
			4'h0: dout = 7'b 0111111;
			4'h1: dout = 7'b 0000110;
			4'h2: dout = 7'b 1011011;
			4'h3: dout = 7'b 1001111;
			4'h4: dout = 7'b 1100110;
			4'h5: dout = 7'b 1101101;
			4'h6: dout = 7'b 1111101;
			4'h7: dout = 7'b 0000111;
			4'h8: dout = 7'b 1111111;
			4'h9: dout = 7'b 1101111;
			4'hA: dout = 7'b 1110111;
			4'hB: dout = 7'b 1111100;
			4'hC: dout = 7'b 0111001;
			4'hD: dout = 7'b 1011110;
			4'hE: dout = 7'b 1111001;
			4'hF: dout = 7'b 1110001;
			default: dout = 7'b 1000000;
		endcase
endmodule
