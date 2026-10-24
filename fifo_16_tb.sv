`timescale 1ns/1ps

module fifo_16_tb_modelsim;

    //========================================================
    // Parameters
    //========================================================
    parameter DATA_WIDTH = 16;
    parameter DEPTH      = 10;

    //========================================================
    // Testbench signals
    //========================================================
    reg                  clk;
    reg                  rst;
    reg                  wr_en;
    reg                  rd_en;
    reg  [DATA_WIDTH-1:0] data_in;

    wire [DATA_WIDTH-1:0] data_out;
    wire                  full;
    wire                  empty;

    //========================================================
    // DUT
    //========================================================
    fifo_16 #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk      (clk),
        .rst      (rst),
        .wr_en    (wr_en),
        .rd_en    (rd_en),
        .data_in  (data_in),
        .data_out (data_out),
        .full     (full),
        .empty    (empty)
    );

    //========================================================
    // Reference model
    //========================================================
    reg [DATA_WIDTH-1:0] expected_mem [0:DEPTH-1];

    integer model_wr_ptr;
    integer model_rd_ptr;
    integer model_count;

    integer errors;
    integer tests;

    //========================================================
    // Clock generation
    // 10 ns clock period
    //========================================================
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    //========================================================
    // Reset task
    //========================================================
    task reset_fifo;
    begin
        @(negedge clk);

        rst    = 1'b1;
        wr_en  = 1'b0;
        rd_en  = 1'b0;
        data_in = 0;

        @(posedge clk);

        @(negedge clk);

        rst = 1'b0;

        // Reset reference model
        model_wr_ptr = 0;
        model_rd_ptr = 0;
        model_count  = 0;

        $display("---------------------------------------------");
        $display("FIFO RESET COMPLETE");
        $display("---------------------------------------------");
    end
    endtask

    //========================================================
    // WRITE TASK
    //========================================================
    task write_data;
        input [DATA_WIDTH-1:0] value;

        reg was_full;
        reg was_empty;
        reg write_accepted;

    begin
        @(negedge clk);

        // Capture FIFO state BEFORE clock edge
        was_full  = full;
        was_empty = empty;

        data_in = value;
        wr_en   = 1'b1;
        rd_en   = 1'b0;

        // Determine whether write will be accepted
        write_accepted =
            wr_en && (!was_full || (rd_en && !was_empty));

        @(posedge clk);

        #1;

        // Update reference model
        if (write_accepted) begin

            expected_mem[model_wr_ptr] = value;

            if (model_wr_ptr == DEPTH-1)
                model_wr_ptr = 0;
            else
                model_wr_ptr = model_wr_ptr + 1;

            model_count = model_count + 1;

            $display("[%0t] WRITE accepted : %0d | Count = %0d",
                     $time, value, model_count);
        end
        else begin
            $display("[%0t] WRITE rejected : FIFO FULL | Data = %0d",
                     $time, value);
        end

        // Check DUT flags
        check_flags;

        wr_en = 1'b0;
    end
    endtask

    //========================================================
    // READ TASK
    //========================================================
    task read_data;

        reg was_empty;
        reg read_accepted;
        reg [DATA_WIDTH-1:0] expected_data;

    begin
        @(negedge clk);

        // Capture FIFO state BEFORE clock edge
        was_empty = empty;

        wr_en = 1'b0;
        rd_en = 1'b1;

        // Determine whether read will be accepted
        read_accepted = rd_en && !was_empty;

        if (read_accepted)
            expected_data = expected_mem[model_rd_ptr];

        @(posedge clk);

        #1;

        if (read_accepted) begin

            // Check data returned by DUT
            if (data_out !== expected_data) begin

                $display("ERROR [%0t] READ DATA MISMATCH",
                         $time);

                $display("        Expected = %0d",
                         expected_data);

                $display("        Actual   = %0d",
                         data_out);

                errors = errors + 1;
            end
            else begin

                $display("[%0t] READ accepted : %0d | Count = %0d",
                         $time, data_out, model_count - 1);

                tests = tests + 1;
            end

            // Update reference read pointer
            if (model_rd_ptr == DEPTH-1)
                model_rd_ptr = 0;
            else
                model_rd_ptr = model_rd_ptr + 1;

            model_count = model_count - 1;
        end
        else begin

            $display("[%0t] READ rejected : FIFO EMPTY",
                     $time);

        end

        // Check DUT flags
        check_flags;

        rd_en = 1'b0;
    end
    endtask

    //========================================================
    // Simultaneous READ + WRITE
    //========================================================
    task read_write_data;
        input [DATA_WIDTH-1:0] write_value;

        reg was_full;
        reg was_empty;

        reg write_accepted;
        reg read_accepted;

        reg [DATA_WIDTH-1:0] expected_read_data;

    begin

        @(negedge clk);

        // Capture PREVIOUS FIFO state
        was_full  = full;
        was_empty = empty;

        wr_en   = 1'b1;
        rd_en   = 1'b1;
        data_in = write_value;

        // Same acceptance logic as DUT
        write_accepted =
            wr_en && (!was_full || (rd_en && !was_empty));

        read_accepted =
            rd_en && !was_empty;

        // Save expected read data before changing model
        if (read_accepted)
            expected_read_data = expected_mem[model_rd_ptr];

        @(posedge clk);

        #1;

        // ---------------------------
        // Check READ
        // ---------------------------
        if (read_accepted) begin

            if (data_out !== expected_read_data) begin

                $display("ERROR [%0t] SIMULTANEOUS READ MISMATCH",
                         $time);

                $display("        Expected = %0d",
                         expected_read_data);

                $display("        Actual   = %0d",
                         data_out);

                errors = errors + 1;
            end
            else begin

                $display("[%0t] SIMULTANEOUS READ : %0d",
                         $time, data_out);

                tests = tests + 1;
            end

            if (model_rd_ptr == DEPTH-1)
                model_rd_ptr = 0;
            else
                model_rd_ptr = model_rd_ptr + 1;

            model_count = model_count - 1;
        end

        // ---------------------------
        // Check WRITE
        // ---------------------------
        if (write_accepted) begin

            expected_mem[model_wr_ptr] = write_value;

            if (model_wr_ptr == DEPTH-1)
                model_wr_ptr = 0;
            else
                model_wr_ptr = model_wr_ptr + 1;

            model_count = model_count + 1;

            $display("[%0t] SIMULTANEOUS WRITE : %0d",
                     $time, write_value);
        end

        check_flags;

        wr_en = 1'b0;
        rd_en = 1'b0;

    end
    endtask

    //========================================================
    // Check FIFO flags
    //========================================================
    task check_flags;

        reg expected_full;
        reg expected_empty;

    begin

        expected_full  = (model_count == DEPTH);
        expected_empty = (model_count == 0);

        if (full !== expected_full) begin

            $display("ERROR [%0t] FULL FLAG MISMATCH",
                     $time);

            $display("        Expected = %b",
                     expected_full);

            $display("        Actual   = %b",
                     full);

            errors = errors + 1;
        end

        if (empty !== expected_empty) begin

            $display("ERROR [%0t] EMPTY FLAG MISMATCH",
                     $time);

            $display("        Expected = %b",
                     expected_empty);

            $display("        Actual   = %b",
                     empty);

            errors = errors + 1;
        end

        // Count should never exceed FIFO depth
        if (model_count > DEPTH) begin

            $display("ERROR [%0t] MODEL COUNT EXCEEDED DEPTH",
                     $time);

            errors = errors + 1;

        end

        // Count should never become negative
        if (model_count < 0) begin

            $display("ERROR [%0t] MODEL COUNT BECAME NEGATIVE",
                     $time);

            errors = errors + 1;

        end

    end
    endtask

    //========================================================
    // RANDOM TRANSACTION
    //========================================================
    task random_transaction;

        reg was_full;
        reg was_empty;

        reg write_accepted;
        reg read_accepted;

        reg [DATA_WIDTH-1:0] random_data;
        reg [DATA_WIDTH-1:0] expected_read_data;

    begin

        @(negedge clk);

        // Generate random stimulus
        wr_en   = $random % 2;
        rd_en   = $random % 2;
        random_data = $random;

        data_in = random_data;

        // Remove negative values from enable
        if (wr_en < 0)
            wr_en = 0;

        if (rd_en < 0)
            rd_en = 0;

        // Capture PRE-CLOCK state
        was_full  = full;
        was_empty = empty;

        // Determine accepted operations
        write_accepted =
            wr_en && (!was_full || (rd_en && !was_empty));

        read_accepted =
            rd_en && !was_empty;

        // Save expected data before model changes
        if (read_accepted)
            expected_read_data = expected_mem[model_rd_ptr];

        @(posedge clk);

        #1;

        // ---------------------------
        // READ CHECK
        // ---------------------------
        if (read_accepted) begin

            if (data_out !== expected_read_data) begin

                $display("ERROR [%0t] RANDOM READ MISMATCH",
                         $time);

                $display("        Expected = %0d",
                         expected_read_data);

                $display("        Actual   = %0d",
                         data_out);

                errors = errors + 1;

            end
            else begin

                tests = tests + 1;

            end

            if (model_rd_ptr == DEPTH-1)
                model_rd_ptr = 0;
            else
                model_rd_ptr = model_rd_ptr + 1;

            model_count = model_count - 1;

        end

        // ---------------------------
        // WRITE MODEL UPDATE
        // ---------------------------
        if (write_accepted) begin

            expected_mem[model_wr_ptr] = random_data;

            if (model_wr_ptr == DEPTH-1)
                model_wr_ptr = 0;
            else
                model_wr_ptr = model_wr_ptr + 1;

            model_count = model_count + 1;

        end

        // Check flags
        check_flags;

        wr_en = 1'b0;
        rd_en = 1'b0;

    end
    endtask

    //========================================================
    // MAIN TEST
    //========================================================
    integer i;

    initial begin

        // Initial values
        rst     = 1'b0;
        wr_en   = 1'b0;
        rd_en   = 1'b0;
        data_in = 0;

        model_wr_ptr = 0;
        model_rd_ptr = 0;
        model_count  = 0;

        errors = 0;
        tests  = 0;

        $display("");
        $display("=============================================");
        $display("        FIFO MODELsim TESTBENCH");
        $display("=============================================");
        $display("DATA_WIDTH = %0d", DATA_WIDTH);
        $display("DEPTH      = %0d", DEPTH);
        $display("=============================================");

        //====================================================
        // TEST 1: RESET
        //====================================================
        reset_fifo;

        //====================================================
        // TEST 2: READ WHEN EMPTY
        //====================================================
        $display("");
        $display("TEST 2: READ WHEN EMPTY");

        read_data;

        //====================================================
        // TEST 3: NORMAL WRITES
        //====================================================
        $display("");
        $display("TEST 3: NORMAL WRITES");

        write_data(8'd11);
        write_data(8'd22);
        write_data(8'd33);

        //====================================================
        // TEST 4: NORMAL READS
        //====================================================
        $display("");
        $display("TEST 4: NORMAL READS");

        read_data;
        read_data;
        read_data;

        //====================================================
        // TEST 5: FILL FIFO
        //====================================================
        $display("");
        $display("TEST 5: FILL FIFO");

        for (i = 0; i < DEPTH; i = i + 1)
            write_data(i + 100);

        //====================================================
        // TEST 6: WRITE WHEN FULL
        //====================================================
        $display("");
        $display("TEST 6: WRITE WHEN FULL");

        write_data(8'd250);

        //====================================================
        // TEST 7: READ FROM FULL FIFO
        //====================================================
        $display("");
        $display("TEST 7: READ FROM FULL FIFO");

        read_data;

        //====================================================
        // TEST 8: SIMULTANEOUS READ + WRITE
        //====================================================
        $display("");
        $display("TEST 8: SIMULTANEOUS READ + WRITE");

        read_write_data(8'd200);
        read_write_data(8'd201);
        read_write_data(8'd202);

        //====================================================
        // TEST 9: EMPTY FIFO AGAIN
        //====================================================
        $display("");
        $display("TEST 9: EMPTY FIFO");

        while (model_count > 0)
            read_data;

        //====================================================
        // TEST 10: RANDOM TESTING
        //====================================================
        $display("");
        $display("TEST 10: RANDOM TESTING");

        for (i = 0; i < 500; i = i + 1)
            random_transaction;

        //====================================================
        // FINAL RESULT
        //====================================================
        $display("");
        $display("=============================================");
        $display("             FINAL TEST RESULT");
        $display("=============================================");

        $display("Total successful read checks = %0d", tests);
        $display("Total errors                 = %0d", errors);
        $display("Reference model count        = %0d", model_count);

        if (errors == 0) begin

            $display("");
            $display("*********************************************");
            $display("*           FIFO TEST PASSED               *");
            $display("*********************************************");

        end
        else begin

            $display("");
            $display("*********************************************");
            $display("*           FIFO TEST FAILED               *");
            $display("*********************************************");

        end

        $display("");

        #20;
        $stop;

    end

endmodule
