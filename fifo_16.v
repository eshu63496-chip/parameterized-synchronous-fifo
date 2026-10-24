module fifo_16 #(
    parameter DATA_WIDTH = 16,
    parameter DEPTH      = 10
)(
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  wr_en,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] data_in,

    output reg  [DATA_WIDTH-1:0] data_out,
    output wire                  full,
    output wire                  empty
);
    localparam ADDR_WIDTH = $clog2(DEPTH);

    reg [DATA_WIDTH-1:0] memory [0:DEPTH-1];

    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    reg [ADDR_WIDTH:0] count;

    wire write_valid;
    wire read_valid;

    // Accepted FIFO operations
    assign write_valid = wr_en &&
                         (!full || (rd_en && !empty));

    assign read_valid  = rd_en && !empty;

    // FIFO status
    assign empty = (count == 0);
    assign full  = (count == DEPTH);

    always @(posedge clk) begin

        if (rst) begin

            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            data_out <= 0;

        end
        else begin

            // Write operation
            if (write_valid) begin
                memory[wr_ptr] <= data_in;
                if(wr_ptr==DEPTH-1)
                   wr_ptr <= 0;
                 else
                wr_ptr <= wr_ptr + 1'b1;
                
            end

            // Read operation
            if (read_valid) begin
                data_out <= memory[rd_ptr];
                if(rd_ptr==DEPTH-1)
                   rd_ptr <= 0;
                 else
                rd_ptr <= rd_ptr + 1'b1;
                
                
            end

            // FIFO count
            case ({write_valid, read_valid})

                2'b10:
                    count <= count + 1'b1;

                2'b01:
                    count <= count - 1'b1;

                2'b11:
                    count <= count;

                2'b00:
                    count <= count;

            endcase

        end

    end

endmodule
