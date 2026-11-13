`timescale 1ns/1ps

// Minimal smoke test for the integrated triangle-to-pixel geometry slice.
// This intentionally checks one known triangle and one output stall before
// the broader scoreboard and randomized verification environment is added.

module geometry_smoke_tb;

    localparam int COORD_WIDTH = 16;
    localparam int PIXEL_WIDTH = 6;
    localparam int PRIMITIVE_ID_WIDTH = 8;

    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic triangle_valid;
    logic triangle_ready;
    logic signed [COORD_WIDTH-1:0] triangle_x0;
    logic signed [COORD_WIDTH-1:0] triangle_y0;
    logic signed [COORD_WIDTH-1:0] triangle_x1;
    logic signed [COORD_WIDTH-1:0] triangle_y1;
    logic signed [COORD_WIDTH-1:0] triangle_x2;
    logic signed [COORD_WIDTH-1:0] triangle_y2;
    logic [PRIMITIVE_ID_WIDTH-1:0] triangle_primitive_id;

    logic pixel_valid;
    logic pixel_ready;
    logic [PIXEL_WIDTH-1:0] pixel_x;
    logic [PIXEL_WIDTH-1:0] pixel_y;
    logic [PRIMITIVE_ID_WIDTH-1:0] pixel_primitive_id;

    int expected_index;
    int stall_cycles;
    logic [PIXEL_WIDTH-1:0] stalled_x;
    logic [PIXEL_WIDTH-1:0] stalled_y;
    logic [PRIMITIVE_ID_WIDTH-1:0] stalled_primitive_id;

    always #5 clk = ~clk;

    graphics_accelerator dut (
        .clk(clk),
        .rst_n(rst_n),
        .triangle_valid(triangle_valid),
        .triangle_ready(triangle_ready),
        .triangle_x0(triangle_x0),
        .triangle_y0(triangle_y0),
        .triangle_x1(triangle_x1),
        .triangle_y1(triangle_y1),
        .triangle_x2(triangle_x2),
        .triangle_y2(triangle_y2),
        .triangle_primitive_id(triangle_primitive_id),
        .pixel_valid(pixel_valid),
        .pixel_ready(pixel_ready),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_primitive_id(pixel_primitive_id)
    );

    task automatic fail(input string message);
        begin
            $display("FAIL: %s", message);
            $fatal(1);
        end
    endtask

    task automatic drive_triangle;
        begin
            // Coordinates are Q12.4: one pixel equals sixteen coordinate units.
            @(negedge clk);
            triangle_x0 = 16'sd16;
            triangle_y0 = 16'sd16;
            triangle_x1 = 16'sd80;
            triangle_y1 = 16'sd16;
            triangle_x2 = 16'sd16;
            triangle_y2 = 16'sd80;
            triangle_primitive_id = 8'd7;
            triangle_valid = 1'b1;

            while (!triangle_ready)
                @(posedge clk);

            @(negedge clk);
            triangle_valid = 1'b0;
        end
    endtask

    task automatic check_pixel(input int expected_x, input int expected_y);
        begin
            if (pixel_x !== expected_x[PIXEL_WIDTH-1:0])
                fail("unexpected pixel x coordinate");
            if (pixel_y !== expected_y[PIXEL_WIDTH-1:0])
                fail("unexpected pixel y coordinate");
            if (pixel_primitive_id !== 8'd7)
                fail("unexpected primitive ID");
            $display("pixel[%0d] = (%0d, %0d), primitive=%0d",
                     expected_index, pixel_x, pixel_y, pixel_primitive_id);
        end
    endtask

    initial begin
        triangle_valid = 1'b0;
        triangle_x0 = '0;
        triangle_y0 = '0;
        triangle_x1 = '0;
        triangle_y1 = '0;
        triangle_x2 = '0;
        triangle_y2 = '0;
        triangle_primitive_id = '0;
        pixel_ready = 1'b0;
        expected_index = 0;

        repeat (2) @(posedge clk);
        rst_n = 1'b1;
        drive_triangle();
        pixel_ready = 1'b1;

        // The right triangle covers these six pixel centers in row-major order.
        while (expected_index < 6) begin
            @(posedge clk);
            #1;

            if (pixel_valid && pixel_ready) begin
                case (expected_index)
                    0: check_pixel(1, 1);
                    1: check_pixel(2, 1);
                    2: check_pixel(3, 1);
                    3: check_pixel(1, 2);
                    4: check_pixel(2, 2);
                    5: check_pixel(1, 3);
                    default: fail("received more pixels than expected");
                endcase

                expected_index = expected_index + 1;

                // Hold the first emitted pixel slot stalled for three cycles.
                if (expected_index == 1) begin
                    stalled_x = pixel_x;
                    stalled_y = pixel_y;
                    stalled_primitive_id = pixel_primitive_id;
                    pixel_ready = 1'b0;
                    for (stall_cycles = 0; stall_cycles < 3; stall_cycles++) begin
                        @(posedge clk);
                        #1;
                        if (!pixel_valid)
                            fail("pixel valid dropped during output stall");
                        if (pixel_x !== stalled_x || pixel_y !== stalled_y ||
                            pixel_primitive_id !== stalled_primitive_id)
                            fail("pixel changed during output stall");
                    end
                    pixel_ready = 1'b1;
                end
            end
        end

        $display("PASS: geometry smoke test emitted six expected pixels");
        $finish;
    end

endmodule

