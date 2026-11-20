`timescale 1ns/1ps

// Multi-frame demo driver. It reads host-projected triangle transactions,
// sends every triangle through the beta RTL, and records accepted pixel data.

module graphics_accelerator_showcase_tb;
    localparam integer FRAME_COUNT = 72;
    localparam integer TRIANGLES_PER_FRAME = 18;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic triangle_valid = 1'b0;
    logic triangle_ready;
    logic signed [15:0] triangle_x0, triangle_y0;
    logic signed [15:0] triangle_x1, triangle_y1;
    logic signed [15:0] triangle_x2, triangle_y2;
    logic [15:0] triangle_depth0, triangle_depth1, triangle_depth2;
    logic [31:0] triangle_color0, triangle_color1, triangle_color2;
    logic [7:0] triangle_primitive_id;

    logic pixel_valid;
    logic pixel_ready = 1'b1;
    logic [5:0] pixel_x, pixel_y;
    logic [7:0] pixel_primitive_id;
    logic [15:0] pixel_depth;
    logic [31:0] pixel_color;

    integer scene_file;
    integer trace_file;
    integer summary_file;
    integer active_frame = 0;
    integer cycle_count = 0;
    integer triangle_count = 0;
    integer depth_fragment_count = 0;
    integer pixel_count = 0;

    integer scanned_fields;
    integer input_frame, input_primitive_id;
    integer x0_raw, y0_raw, x1_raw, y1_raw, x2_raw, y2_raw;
    integer z0, z1, z2;
    logic [31:0] rgba0, rgba1, rgba2;
    integer frame_index, triangle_index;

    always #5 clk = ~clk;

    graphics_accelerator_beta accelerator (
        .clk(clk), .rst_n(rst_n),
        .triangle_valid(triangle_valid), .triangle_ready(triangle_ready),
        .triangle_x0(triangle_x0), .triangle_y0(triangle_y0),
        .triangle_x1(triangle_x1), .triangle_y1(triangle_y1),
        .triangle_x2(triangle_x2), .triangle_y2(triangle_y2),
        .triangle_depth0(triangle_depth0),
        .triangle_depth1(triangle_depth1),
        .triangle_depth2(triangle_depth2),
        .triangle_color0(triangle_color0),
        .triangle_color1(triangle_color1),
        .triangle_color2(triangle_color2),
        .triangle_primitive_id(triangle_primitive_id),
        .pixel_valid(pixel_valid), .pixel_ready(pixel_ready),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_primitive_id(pixel_primitive_id),
        .pixel_depth(pixel_depth), .pixel_color(pixel_color)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            cycle_count <= 0;
            triangle_count <= 0;
            depth_fragment_count <= 0;
            pixel_count <= 0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (triangle_valid && triangle_ready)
                triangle_count <= triangle_count + 1;
            if (accelerator.fragment_valid && accelerator.fragment_ready)
                depth_fragment_count <= depth_fragment_count + 1;
            if (pixel_valid && pixel_ready) begin
                $fwrite(trace_file, "%0d,%0d,%0d,%0d,%0d,%0d,%08x\n",
                        active_frame, cycle_count, pixel_x, pixel_y,
                        pixel_primitive_id, pixel_depth, pixel_color);
                pixel_count <= pixel_count + 1;
            end
        end
    end

    initial begin
        triangle_x0 = 0; triangle_y0 = 0;
        triangle_x1 = 0; triangle_y1 = 0;
        triangle_x2 = 0; triangle_y2 = 0;
        triangle_depth0 = 0; triangle_depth1 = 0; triangle_depth2 = 0;
        triangle_color0 = 0; triangle_color1 = 0; triangle_color2 = 0;
        triangle_primitive_id = 0;

        scene_file = $fopen("results/demo/generated/showcase/scene_triangles.dat", "r");
        trace_file = $fopen("results/demo/generated/showcase/video_pixel_trace.csv", "w");
        summary_file = $fopen("results/demo/generated/showcase/video_run_summary.csv", "w");
        if (scene_file == 0 || trace_file == 0 || summary_file == 0)
            $fatal(1, "Could not open video demo input/output files");
        $fdisplay(trace_file, "frame,cycle,x,y,primitive_id,depth,rgba");
        $fdisplay(summary_file, "frame,triangles,depth_fragments,pixels_emitted,cycles");

        for (frame_index = 0; frame_index < FRAME_COUNT; frame_index = frame_index + 1) begin
            active_frame = frame_index;
            rst_n = 1'b0;
            repeat (3) @(negedge clk);
            rst_n = 1'b1;

            for (triangle_index = 0; triangle_index < TRIANGLES_PER_FRAME;
                 triangle_index = triangle_index + 1) begin
                scanned_fields = $fscanf(scene_file,
                    "%d %d %d %d %d %d %d %d %d %d %d %h %h %h\n",
                    input_frame, input_primitive_id,
                    x0_raw, y0_raw, x1_raw, y1_raw, x2_raw, y2_raw,
                    z0, z1, z2, rgba0, rgba1, rgba2);
                if (scanned_fields != 14)
                    $fatal(1, "Bad or incomplete scene data at frame %0d triangle %0d",
                           frame_index, triangle_index);
                if (input_frame != frame_index)
                    $fatal(1, "Scene frame order mismatch: expected %0d, got %0d",
                           frame_index, input_frame);

                submit_triangle(x0_raw, y0_raw, x1_raw, y1_raw, x2_raw, y2_raw,
                                z0, z1, z2, rgba0, rgba1, rgba2,
                                input_primitive_id[7:0]);
            end

            wait ((accelerator.rasterizer_stage.state == 0) &&
                  !accelerator.setup_out_valid &&
                  !accelerator.raster_pixel_valid &&
                  !accelerator.fragment_valid && !pixel_valid);
            repeat (2) @(negedge clk);
            $fdisplay(summary_file, "%0d,%0d,%0d,%0d,%0d", frame_index,
                      triangle_count, depth_fragment_count, pixel_count, cycle_count);
            $display("Frame %0d: %0d triangles, %0d accepted pixels, %0d depth rejections",
                     frame_index, triangle_count, pixel_count,
                     depth_fragment_count - pixel_count);
        end

        $fclose(scene_file);
        $fclose(trace_file);
        $fclose(summary_file);
        $display("Completed %0d RTL-rendered frames", FRAME_COUNT);
        $finish;
    end

    task automatic submit_triangle(
        input integer in_x0, input integer in_y0,
        input integer in_x1, input integer in_y1,
        input integer in_x2, input integer in_y2,
        input integer in_z0, input integer in_z1, input integer in_z2,
        input logic [31:0] in_rgba0,
        input logic [31:0] in_rgba1,
        input logic [31:0] in_rgba2,
        input logic [7:0] in_primitive_id
    );
        begin
            @(negedge clk);
            while (triangle_ready !== 1'b1) @(negedge clk);
            triangle_x0 = 0; triangle_y0 = 0;
            triangle_x1 = 0; triangle_y1 = 0;
            triangle_x2 = 0; triangle_y2 = 0;
            @(negedge clk);
            triangle_x0 = in_x0; triangle_y0 = in_y0;
            triangle_x1 = in_x1; triangle_y1 = in_y1;
            triangle_x2 = in_x2; triangle_y2 = in_y2;
            triangle_depth0 = in_z0[15:0];
            triangle_depth1 = in_z1[15:0];
            triangle_depth2 = in_z2[15:0];
            triangle_color0 = in_rgba0;
            triangle_color1 = in_rgba1;
            triangle_color2 = in_rgba2;
            triangle_primitive_id = in_primitive_id;
            triangle_valid = 1'b1;
            do @(posedge clk); while (triangle_ready !== 1'b1);
            @(negedge clk);
            triangle_valid = 1'b0;
        end
    endtask

    initial begin
        #100000000;
        $fatal(1, "Video demo did not complete before timeout");
    end
endmodule
