module Final_Project(
							selects, clk, reset_raw, start_stop,
							hex0, hex1, hex2, hex3, hex4, hex5,
							);
	
	input [4:0] selects;
	input clk;
	input reset_raw;
	input start_stop;
	
	output [6:0] hex0, hex1, hex2, hex3, hex4, hex5;
	
	wire reset;
	
	reg [2:0] time_index;
	
	wire  [23:0] curr_time;
	wire  [23:0] disp_time;
	
	//debounce reset push button
	debouncer reset_debounce(clk, reset_raw, reset);
	
	//increase time for displays
	counter count(clk, reset, start_stop, curr_time);
	
	//store new time on reset
	time_storage(curr_time, reset, time_index, disp_time);
	
	//display current time
	FinalDisplay disp(disp_time, hex0, hex1, hex2, hex3, hex4, hex5);
	
	
	//select with time to display with the highest switch priority, no switches means current stopwatch time
	always @(selects)
	begin
		
		casex(selects)
			5'b00000: time_index <= 0;
			5'b00001: time_index <= 1;
			5'b0001x: time_index <= 2;
			5'b001xx: time_index <= 3;
			5'b01xxx: time_index <= 4;
			5'b1xxxx: time_index <= 5;
		endcase
		
	end

endmodule

//module to change the 24 bit current time register when clock running
module counter(clk, reset, stop, time_bits);
	input clk, reset, stop;
	output [23:0] time_bits;
	
	wire [3:0] ms, sec1, sec10, min1, min10, hr;
	wire ten_clk;
	
	//change 50MHz clock to 10 Hz clock
	Timer timer(clk, reset, ten_clk);
	
	assign time_bits[3:0] = ms;
	assign time_bits[7:4] = sec1;
	assign time_bits[11:8] = sec10;
	assign time_bits[15:12] = min1;
	assign time_bits[19:16] = min10;
	assign time_bits[23:20] = hr;
	
	//count up for each SSD display at different rates
	integer_timer #(10, 1) msTime(ten_clk, ms, stop, reset);
	integer_timer #(10, 10) sec1Time(ten_clk, sec1, stop, reset);
	integer_timer #(6, 100) sec10Time(ten_clk, sec10, stop, reset);
	integer_timer #(10, 600) min1Time(ten_clk, min1, stop, reset);
	integer_timer #(6, 6000) min10Time(ten_clk, min10, stop, reset);
	integer_timer #(10, 36000) hrTime(ten_clk, hr, stop, reset);
	
endmodule

//change 50MHz clock to 10Hz clock
module Timer(Clk_50M, reset, Clk_10);

	input Clk_50M, reset;
	output Clk_10;

	reg Clk_10 = 1'b0;
	reg [22:0]counter;

	always@(posedge Clk_50M)
		begin
			if (reset == 1'b1) //reset counter on reset
				begin
					Clk_10 <= 0;
					counter <= 0;
				end

			counter <= counter + 1; //count until .1 seconds
			if (counter == 5_000_000)
				begin
					Clk_10 <= ~Clk_10; //flip 10 Hz clock
					counter <= 0; 
				end

		end
endmodule

//increases 4 bit register by one after a certain amount of 10 Hz clock cycles
module integer_timer(clock, time_bits, stop, reset);
	
	parameter ten_or_six = 10;
	parameter clock_cycles = 5_000_000;
	
	input clock, stop, reset;
		
	integer count = 0;
		
	output reg [3:0] time_bits = 0;
	
	always @(posedge clock, negedge reset)
		begin
			if (!reset) //set both the time and the count to zero if reset pressed
				begin 
					time_bits <= 0;
					count <=0;
				end
				
			else
				begin
			
				if (stop == 0) //check that the clock is not stopped
					begin
						//counter loops back to zero after either 6 or 10 count increases
						if (count == (clock_cycles * ten_or_six) - 1)
							count <= 0;
			
						else
							count <= count + 1; 
				
						//increase time when count is a multiple of clock cycles
						time_bits <= count / clock_cycles;
					end

				end
		end
	
	
endmodule

//reset pushbutton debouncing module
module debouncer( clk, key, keydb); // It a delay subroutine to check possible debouncing of input pushbuttons.
	
	input clk,key; // The clk input will be assigned to system_clock input on main module and key is assigned to desired
						// pushbutton.
						
	output reg keydb; // The keydb output handle the debounced pushbutton output. It will be assigned to wire
							// debounced_pushb of the main module.
	
	reg key1, key2;
	reg [15:0] count;
	
	always @(posedge clk)
	begin
		key1 <= key; key2 <= key1;
		
		if(keydb==key2)
			count <= 0;
		else
		begin
			count <= count + 1'b1;
			
			if(count == 16'hffff)
				keydb <= ~keydb;
		end
	end
endmodule

//module to store and access 5 previous times
module time_storage(in_time, clk, index, out_time);//uses nonblocking assignment
	
	/*
		stores times in 2d array
		individual time is accessed at mem[index]
		mem[0] is the current time
		mem[1] to mem[n] are stored times
	*/

	parameter time_length = 24;//length in bits of time value
	parameter num_times = 5;//number of times stored
	
	input clk;//clock for moving times along
	input [2:0] index;//index of time to display
	input [time_length-1 : 0] in_time;
	
	output [time_length-1 : 0] out_time;//output time
	
	reg [time_length-1 : 0] mem [num_times : 0];//storage array
		
	assign out_time = mem[index];
	
	integer i, j;//loop variables
	
	//assigning mem[0] to in_time
	always @(in_time)
	begin
		
		for (j=0; j<time_length; j=j+1)
		begin
			mem[0][j] <= in_time[j];
		end
		
	end
	
	//shift register: loads in mem[0] on clock
	//shifts data one over
	always @(negedge clk)
	begin
	
	for (i=0; i<num_times+1; i=i+1)
		begin: first_loop
		
		for (j=0; j<time_length; j=j+1)
			begin: second_loop
				
				if (i > 0)
					mem[i][j] <= mem[i-1][j];//others take input from next time in storage array
					
			end
			
		end
		
	end
	
endmodule

//module to display time on all SSDs
module FinalDisplay(number,hex0,hex1,hex2,hex3,hex4,hex5);
input [23:0] number;//time to be displayed
output reg [6:0] hex0,hex1,hex2,hex3,hex4,hex5;//SSDs
wire [3:0] num0,num1,num2,num3,num4,num5;//each SSD number

assign num0[0] = number[0];//tenth of a second
assign num0[1] = number[1];
assign num0[2] = number[2];
assign num0[3] = number[3];

assign num1[0] = number[4];//one second
assign num1[1] = number[5];
assign num1[2] = number[6];
assign num1[3] = number[7];

assign num2[0] = number[8];//ten second
assign num2[1] = number[9];
assign num2[2] = number[10];
assign num2[3] = number[11];

assign num3[0] = number[12];//one minute
assign num3[1] = number[13];
assign num3[2] = number[14];
assign num3[3] = number[15];

assign num4[0] = number[16];//ten minute
assign num4[1] = number[17];
assign num4[2] = number[18];
assign num4[3] = number[19];

assign num5[0] = number[20];//one hour
assign num5[1] = number[21];
assign num5[2] = number[22];
assign num5[3] = number[23];

always@(num0,num1,num2,num3,num4,num5)
	begin
		case(num0)//tenth of a second
		4'b0000:hex0 = 7'b0000001;//0
		4'b0001:hex0 = 7'b1001111;//1
		4'b0010:hex0 = 7'b0010010;//2
		4'b0011:hex0 = 7'b0000110;//3
		4'b0100:hex0 = 7'b1001100;//4
		4'b0101:hex0 = 7'b0100100;//5
		4'b0110:hex0 = 7'b0100000;//6
		4'b0111:hex0 = 7'b0001111;//7
		4'b1000:hex0 = 7'b0000000;//8
		4'b1001:hex0 = 7'b0000100;//9
		endcase
		case(num1)//1 second
		4'b0000:hex1 = 7'b0000001;//0
		4'b0001:hex1 = 7'b1001111;//1
		4'b0010:hex1 = 7'b0010010;//2
		4'b0011:hex1 = 7'b0000110;//3
		4'b0100:hex1 = 7'b1001100;//4
		4'b0101:hex1 = 7'b0100100;//5
		4'b0110:hex1 = 7'b0100000;//6
		4'b0111:hex1 = 7'b0001111;//7
		4'b1000:hex1 = 7'b0000000;//8
		4'b1001:hex1 = 7'b0000100;//9
		endcase
		case(num2)//10 second
		4'b0000:hex2 = 7'b0000001;//0
		4'b0001:hex2 = 7'b1001111;//1
		4'b0010:hex2 = 7'b0010010;//2
		4'b0011:hex2 = 7'b0000110;//3
		4'b0100:hex2 = 7'b1001100;//4
		4'b0101:hex2 = 7'b0100100;//5
		endcase
		case(num3)//1 minute
		4'b0000:hex3 = 7'b0000001;//0
		4'b0001:hex3 = 7'b1001111;//1
		4'b0010:hex3 = 7'b0010010;//2
		4'b0011:hex3 = 7'b0000110;//3
		4'b0100:hex3 = 7'b1001100;//4
		4'b0101:hex3 = 7'b0100100;//5
		4'b0110:hex3 = 7'b0100000;//6
		4'b0111:hex3 = 7'b0001111;//7
		4'b1000:hex3 = 7'b0000000;//8
		4'b1001:hex3 = 7'b0000100;//9
		endcase
		case(num4)//10 minute
		4'b0000:hex4 = 7'b0000001;//0
		4'b0001:hex4 = 7'b1001111;//1
		4'b0010:hex4 = 7'b0010010;//2
		4'b0011:hex4 = 7'b0000110;//3
		4'b0100:hex4 = 7'b1001100;//4
		4'b0101:hex4 = 7'b0100100;//5
		endcase
		case(num5)//1 hour
		4'b0000:hex5 = 7'b0000001;//0
		4'b0001:hex5 = 7'b1001111;//1
		4'b0010:hex5 = 7'b0010010;//2
		4'b0011:hex5 = 7'b0000110;//3
		4'b0100:hex5 = 7'b1001100;//4
		4'b0101:hex5 = 7'b0100100;//5
		4'b0110:hex5 = 7'b0100000;//6
		4'b0111:hex5 = 7'b0001111;//7
		4'b1000:hex5 = 7'b0000000;//8
		4'b1001:hex5 = 7'b0000100;//9
		endcase
	end
endmodule 