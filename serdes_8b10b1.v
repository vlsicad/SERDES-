`timescale 1ns/1ns

module serdes_8b10b (
    input        clk_tx,     // Transmitter clock
    input        reset,      // System reset
    input  [7:0] data_in,    // 8-bit parallel input data
    input        valid_in,   // Input valid signal
    output       serial_out, // Serialized high-speed output
    input 		 load,
    output [7:0] data_out,   // 8-bit parallel output data
    output       valid_out   // Output valid signal
);

    // Transmitter (SER)
    wire [9:0] encoded_data;
	
	
    wire serial_tx;

    encoder_8b10b encoder (
        .data_in(data_in),
        .valid(valid_in),
        .encoded_data(encoded_data)
    );

    serializer serializer (
        .clk(clk_tx),
        .reset(reset),
		.load(load),
        .parallel_data(encoded_data),
        .serial_out(serial_out)
    );

    // Receiver (DES)
    wire [9:0] deserialized_data;

    deserializer deserializer (
        .clk(clk_tx),
        .reset(reset),
        .serial_in(serial_out),
        .parallel_data(deserialized_data)
    );

    decoder_8b10b decoder (
        .clk(clk_tx),
        .encoded_data(deserialized_data),
        .data_out(data_out),
        .valid(valid_out)
    );

endmodule

module encoder_8b10b (
    input  [7:0] data_in,       // 8-bit parallel input data
    input        valid,         // Input valid signal
    output [9:0] encoded_data   // 10-bit encoded output
);

    reg [3:0] temp_4b;
    reg [5:0] temp_6b;
    reg [9:0] data_10b_out;

    always @(*) begin
        // Default values
        temp_4b = 4'b0000;
        temp_6b = 6'b000000;

        // Map upper 3 bits (MSBs) to 4-bit output
        case (data_in[7:5])
            3'b000: temp_4b = 4'b0100;
            3'b001: temp_4b = 4'b1001;
            3'b010: temp_4b = 4'b0101;
            3'b011: temp_4b = 4'b0011;
            3'b100: temp_4b = 4'b0010;
            3'b101: temp_4b = 4'b1010;
            3'b110: temp_4b = 4'b0110;
            3'b111: temp_4b = 4'b0001;
            default: temp_4b = 4'b0000;
        endcase

        // Map lower 5 bits (LSBs) to 6-bit output
        case (data_in[4:0])
            5'b00000: temp_6b = 6'b011000;
            5'b00001: temp_6b = 6'b011101;
            5'b00010: temp_6b = 6'b010010;
            5'b00011: temp_6b = 6'b110001;
            5'b00100: temp_6b = 6'b110101;
            5'b00101: temp_6b = 6'b101001;
            5'b00110: temp_6b = 6'b011001;
            5'b00111: temp_6b = 6'b111000;
            5'b01000: temp_6b = 6'b111001;
            5'b01001: temp_6b = 6'b100101;
            5'b01010: temp_6b = 6'b010101;
            5'b01011: temp_6b = 6'b110100;
            5'b01100: temp_6b = 6'b001101;
            5'b01101: temp_6b = 6'b101100;
            5'b01110: temp_6b = 6'b011100;
            5'b01111: temp_6b = 6'b010111;
            default: temp_6b = 6'b000000;
        endcase

        data_10b_out = {temp_4b, temp_6b};
    end

    assign encoded_data = valid ? 10'b0000000000 : data_10b_out  ;

endmodule


module serializer (
    input        clk,
    input        reset,
    input        load,             // Load signal to load parallel_data
    input  [9:0] parallel_data,    // 10-bit parallel data input
    output       serial_out        // Serialized output
);
    reg [9:0] shift_reg;

    always @(posedge clk or posedge reset) begin
        if (reset)
            shift_reg <= 10'b0; // Reset shift register
        else if (load)
            shift_reg <= parallel_data; // Load parallel data into the shift register
        else
            shift_reg <= {shift_reg[8:0], 1'b0}; // Shift left, insert 0 at LSB
    end

    assign serial_out = shift_reg[9]; // Output the MSB
endmodule


module deserializer (
    input        clk,
    input        reset,
    input        serial_in,
    output [9:0] parallel_data
);
    reg [9:0] shift_reg;

    always @(posedge clk or posedge reset) begin
        if (reset)
            shift_reg <= 10'b0;
        else
            shift_reg <= {shift_reg[8:0], serial_in}; // Shift LSB in
    end

    assign parallel_data = shift_reg;
endmodule

module decoder_8b10b (
	input clk,
    input  [9:0] encoded_data, // 10-bit encoded input
    output [7:0] data_out,     // 8-bit parallel decoded output
    output       valid         // Output valid signal
);

    reg [2:0] temp_3b;
    reg [4:0] temp_5b;
    reg [7:0] data_8b_out;
    reg       is_valid;

    always @(posedge clk) begin
        // Default values
        temp_3b = 3'b000;
        temp_5b = 5'b00000;
        is_valid = 1'b1;

        // Decode MSBs (4 bits to 3 bits)
        case (encoded_data[9:6])
            4'b0100: temp_3b = 3'b000;
            4'b1001: temp_3b = 3'b001;
            4'b0101: temp_3b = 3'b010;
            4'b0011: temp_3b = 3'b011;
            4'b0010: temp_3b = 3'b100;
            4'b1010: temp_3b = 3'b101;
            4'b0110: temp_3b = 3'b110;
            4'b0001: temp_3b = 3'b111;
            default: is_valid = 1'b0;
        endcase

        // Decode LSBs (6 bits to 5 bits)
        case (encoded_data[5:0])
            6'b011000: temp_5b = 5'b00000;
            6'b011101: temp_5b = 5'b00001;
            6'b010010: temp_5b = 5'b00010;
            6'b110001: temp_5b = 5'b00011;
            6'b110101: temp_5b = 5'b00100;
            6'b101001: temp_5b = 5'b00101;
            6'b011001: temp_5b = 5'b00110;
            6'b111000: temp_5b = 5'b00111;
            6'b111001: temp_5b = 5'b01000;
            6'b100101: temp_5b = 5'b01001;
            6'b010101: temp_5b = 5'b01010;
            6'b110100: temp_5b = 5'b01011;
            6'b001101: temp_5b = 5'b01100;
            6'b101100: temp_5b = 5'b01101;
            6'b011100: temp_5b = 5'b01110;
            6'b010111: temp_5b = 5'b01111;
            default: is_valid = 1'b0;
        endcase

        data_8b_out = {temp_3b, temp_5b};
    end

    assign data_out = data_8b_out;
    assign valid = is_valid;

endmodule


`timescale 1ns/1ps

module tb_serdes_8b10b;

    // Parameters
    reg clk_tx;              // Transmitter clock
//  reg clk_rx;              // Receiver clock
    reg reset;               // System reset
    reg [7:0] data_in;       // 8-bit parallel input data
    reg valid_in;            // Input valid signal
    wire serial_out;         // Serialized high-speed output
 // reg serial_in;           // Serialized high-speed input
    wire [7:0] data_out;     // 8-bit parallel output data
    wire valid_out;          // Output valid signal
	reg load;
    // Instantiate the DUT
    serdes_8b10b uut (
        .clk_tx(clk_tx),
        .reset(reset),
        .data_in(data_in),
        .valid_in(valid_in),
        .serial_out(serial_out),
       	.load(load),
        .data_out(data_out),
        .valid_out(valid_out)
    );

    // Generate transmitter clock (100 MHz)
    initial clk_tx = 0;
    always #5 clk_tx = ~clk_tx;

    // Generate receiver clock (50 MHz)
   // initial clk_rx = 0;
   // always #10 clk_rx = ~clk_rx;

    // Testbench stimulus
    initial begin
        // Initialize inputs
        
        reset = 1;
        data_in = 8'b0;
        valid_in = 0;
     //   serial_in = 0;
	load = 0;
        // Apply reset
        #20;
        reset = 0;

        // Send first data byte
        @(posedge clk_tx);
        data_in = 8'hA5;   // Example data
        valid_in = 1;

        @(posedge clk_tx);
        valid_in = 0;      // Deassert valid after sending data	 
		 @(posedge clk_tx);
		load = 1; 
		 @(posedge clk_tx);
		load = 0;
        // Wait for deserialization at the receiver
        #280;

        // Send another data byte
        @(posedge clk_tx);
        data_in = 8'h45;   // Another example data
        valid_in = 1;

        @(posedge clk_tx);
        valid_in = 0;      // Deassert valid
		 @(posedge clk_tx);
		load = 1; 
		 @(posedge clk_tx);
		load = 0;
        // Wait for deserialization
        #280;

        // Terminate simulation
        $finish;
    end

    // Loopback the serialized output to the input
 //   always @(posedge clk_tx) begin
   //     serial_in <= serial_out;
   // end

    // Monitor signals
    initial begin
        $monitor("Time=%t | Data_in=%h | Valid_in=%b | Serial_out=%b | Data_out=%h | Valid_out=%b",
                 $time, data_in, valid_in, serial_out, data_out, valid_out);
    end

endmodule
