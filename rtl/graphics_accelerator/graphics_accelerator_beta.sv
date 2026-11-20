// Full limited-scope beta pipeline.
//
// Triangle attributes enter with geometry, move through setup and
// rasterization, are interpolated at covered pixel centers, and then pass
// through a bounded depth test before becoming final pixel outputs. This
// module intentionally stops before shaders, textures, blending, or memory
// bandwidth optimization.

module graphics_accelerator_beta #(
    parameter int COORD_WIDTH = 16,
    parameter int PIXEL_WIDTH = 6,
    parameter int COORD_FRAC_BITS = 4,
    parameter int PRIMITIVE_ID_WIDTH = 8,
    parameter int FRAMEBUFFER_WIDTH = 64,
    parameter int FRAMEBUFFER_HEIGHT = 64,
    parameter int EDGE_WIDTH = 2*COORD_WIDTH + 2,
    parameter int DEPTH_WIDTH = 16,
    parameter int COLOR_WIDTH = 8
) (
    input logic clk,
    input logic rst_n,

    input logic triangle_valid,
    output logic triangle_ready,
    input logic signed [COORD_WIDTH-1:0] triangle_x0,
    input logic signed [COORD_WIDTH-1:0] triangle_y0,
    input logic signed [COORD_WIDTH-1:0] triangle_x1,
    input logic signed [COORD_WIDTH-1:0] triangle_y1,
    input logic signed [COORD_WIDTH-1:0] triangle_x2,
    input logic signed [COORD_WIDTH-1:0] triangle_y2,
    input logic [DEPTH_WIDTH-1:0] triangle_depth0,
    input logic [DEPTH_WIDTH-1:0] triangle_depth1,
    input logic [DEPTH_WIDTH-1:0] triangle_depth2,
    input logic [4*COLOR_WIDTH-1:0] triangle_color0,
    input logic [4*COLOR_WIDTH-1:0] triangle_color1,
    input logic [4*COLOR_WIDTH-1:0] triangle_color2,
    input logic [PRIMITIVE_ID_WIDTH-1:0] triangle_primitive_id,

    output logic pixel_valid,
    input logic pixel_ready,
    output logic [PIXEL_WIDTH-1:0] pixel_x,
    output logic [PIXEL_WIDTH-1:0] pixel_y,
    output logic [PRIMITIVE_ID_WIDTH-1:0] pixel_primitive_id,
    output logic [DEPTH_WIDTH-1:0] pixel_depth,
    output logic [4*COLOR_WIDTH-1:0] pixel_color
);

    logic setup_in_ready;
    logic setup_out_valid;
    logic setup_out_ready;
    logic setup_degenerate;
    logic signed [COORD_WIDTH-1:0] setup_x0, setup_y0;
    logic signed [COORD_WIDTH-1:0] setup_x1, setup_y1;
    logic signed [COORD_WIDTH-1:0] setup_x2, setup_y2;
    logic [DEPTH_WIDTH-1:0] setup_depth0, setup_depth1, setup_depth2;
    logic [4*COLOR_WIDTH-1:0] setup_color0, setup_color1, setup_color2;
    logic [PRIMITIVE_ID_WIDTH-1:0] setup_primitive_id;
    logic signed [EDGE_WIDTH-1:0] setup_area;
    logic signed [COORD_WIDTH-1:0] setup_x_min, setup_x_max;
    logic signed [COORD_WIDTH-1:0] setup_y_min, setup_y_max;
    logic signed [COORD_WIDTH:0] setup_edge_a0, setup_edge_b0;
    logic signed [EDGE_WIDTH-1:0] setup_edge_c0;
    logic signed [COORD_WIDTH:0] setup_edge_a1, setup_edge_b1;
    logic signed [EDGE_WIDTH-1:0] setup_edge_c1;
    logic signed [COORD_WIDTH:0] setup_edge_a2, setup_edge_b2;
    logic signed [EDGE_WIDTH-1:0] setup_edge_c2;
    logic [2:0] setup_top_left;

    logic raster_setup_valid;
    logic raster_setup_ready;
    logic raster_pixel_valid;
    logic raster_pixel_ready;
    logic [PIXEL_WIDTH-1:0] raster_pixel_x, raster_pixel_y;
    logic [PRIMITIVE_ID_WIDTH-1:0] raster_pixel_primitive_id;

    logic context_valid;
    logic signed [EDGE_WIDTH-1:0] context_area;
    logic signed [COORD_WIDTH:0] context_edge_a0, context_edge_b0;
    logic signed [EDGE_WIDTH-1:0] context_edge_c0;
    logic signed [COORD_WIDTH:0] context_edge_a1, context_edge_b1;
    logic signed [EDGE_WIDTH-1:0] context_edge_c1;
    logic signed [COORD_WIDTH:0] context_edge_a2, context_edge_b2;
    logic signed [EDGE_WIDTH-1:0] context_edge_c2;
    logic [DEPTH_WIDTH-1:0] context_depth0, context_depth1, context_depth2;
    logic [4*COLOR_WIDTH-1:0] context_color0, context_color1, context_color2;

    logic fragment_valid;
    logic fragment_ready;
    logic [PIXEL_WIDTH-1:0] fragment_x, fragment_y;
    logic [PRIMITIVE_ID_WIDTH-1:0] fragment_primitive_id;
    logic [DEPTH_WIDTH-1:0] fragment_depth;
    logic [4*COLOR_WIDTH-1:0] fragment_color;

    assign triangle_ready = setup_in_ready;
    assign setup_out_ready = raster_setup_ready;
    assign raster_setup_valid = setup_out_valid && !setup_degenerate;

    triangle_setup_beta #(
        .COORD_WIDTH(COORD_WIDTH),
        .PRIMITIVE_ID_WIDTH(PRIMITIVE_ID_WIDTH),
        .COORD_FRAC_BITS(COORD_FRAC_BITS),
        .FRAMEBUFFER_WIDTH(FRAMEBUFFER_WIDTH),
        .FRAMEBUFFER_HEIGHT(FRAMEBUFFER_HEIGHT),
        .EDGE_WIDTH(EDGE_WIDTH),
        .DEPTH_WIDTH(DEPTH_WIDTH),
        .COLOR_WIDTH(COLOR_WIDTH)
    ) setup_stage (
        .clk(clk), .rst_n(rst_n),
        .in_valid(triangle_valid), .in_ready(setup_in_ready),
        .in_x0(triangle_x0), .in_y0(triangle_y0),
        .in_x1(triangle_x1), .in_y1(triangle_y1),
        .in_x2(triangle_x2), .in_y2(triangle_y2),
        .in_depth0(triangle_depth0), .in_depth1(triangle_depth1),
        .in_depth2(triangle_depth2),
        .in_color0(triangle_color0), .in_color1(triangle_color1),
        .in_color2(triangle_color2),
        .in_primitive_id(triangle_primitive_id),
        .out_valid(setup_out_valid), .out_ready(setup_out_ready),
        .out_x0(setup_x0), .out_y0(setup_y0),
        .out_x1(setup_x1), .out_y1(setup_y1),
        .out_x2(setup_x2), .out_y2(setup_y2),
        .out_depth0(setup_depth0), .out_depth1(setup_depth1),
        .out_depth2(setup_depth2),
        .out_color0(setup_color0), .out_color1(setup_color1),
        .out_color2(setup_color2),
        .out_primitive_id(setup_primitive_id), .out_area(setup_area),
        .out_degenerate(setup_degenerate),
        .out_x_min(setup_x_min), .out_x_max(setup_x_max),
        .out_y_min(setup_y_min), .out_y_max(setup_y_max),
        .out_edge_a0(setup_edge_a0), .out_edge_b0(setup_edge_b0),
        .out_edge_c0(setup_edge_c0),
        .out_edge_a1(setup_edge_a1), .out_edge_b1(setup_edge_b1),
        .out_edge_c1(setup_edge_c1),
        .out_edge_a2(setup_edge_a2), .out_edge_b2(setup_edge_b2),
        .out_edge_c2(setup_edge_c2), .out_top_left(setup_top_left)
    );

    rasterizer #(
        .COORD_WIDTH(COORD_WIDTH), .PIXEL_WIDTH(PIXEL_WIDTH),
        .COORD_FRAC_BITS(COORD_FRAC_BITS),
        .PRIMITIVE_ID_WIDTH(PRIMITIVE_ID_WIDTH), .EDGE_WIDTH(EDGE_WIDTH)
    ) rasterizer_stage (
        .clk(clk), .rst_n(rst_n),
        .setup_valid(raster_setup_valid), .setup_ready(raster_setup_ready),
        .setup_x_min(setup_x_min), .setup_x_max(setup_x_max),
        .setup_y_min(setup_y_min), .setup_y_max(setup_y_max),
        .setup_edge_a0(setup_edge_a0), .setup_edge_b0(setup_edge_b0),
        .setup_edge_c0(setup_edge_c0),
        .setup_edge_a1(setup_edge_a1), .setup_edge_b1(setup_edge_b1),
        .setup_edge_c1(setup_edge_c1),
        .setup_edge_a2(setup_edge_a2), .setup_edge_b2(setup_edge_b2),
        .setup_edge_c2(setup_edge_c2), .setup_top_left(setup_top_left),
        .setup_primitive_id(setup_primitive_id),
        .pixel_valid(raster_pixel_valid), .pixel_ready(raster_pixel_ready),
        .pixel_x(raster_pixel_x), .pixel_y(raster_pixel_y),
        .pixel_primitive_id(raster_pixel_primitive_id)
    );

    fragment_interpolator #(
        .COORD_WIDTH(COORD_WIDTH), .PIXEL_WIDTH(PIXEL_WIDTH),
        .COORD_FRAC_BITS(COORD_FRAC_BITS),
        .PRIMITIVE_ID_WIDTH(PRIMITIVE_ID_WIDTH), .EDGE_WIDTH(EDGE_WIDTH),
        .DEPTH_WIDTH(DEPTH_WIDTH), .COLOR_WIDTH(COLOR_WIDTH)
    ) interpolator_stage (
        .clk(clk), .rst_n(rst_n),
        .pixel_valid(raster_pixel_valid), .pixel_ready(raster_pixel_ready),
        .pixel_x(raster_pixel_x), .pixel_y(raster_pixel_y),
        .pixel_primitive_id(raster_pixel_primitive_id),
        .triangle_area(context_area),
        .edge_a0(context_edge_a0), .edge_b0(context_edge_b0), .edge_c0(context_edge_c0),
        .edge_a1(context_edge_a1), .edge_b1(context_edge_b1), .edge_c1(context_edge_c1),
        .edge_a2(context_edge_a2), .edge_b2(context_edge_b2), .edge_c2(context_edge_c2),
        .vertex_depth0(context_depth0), .vertex_depth1(context_depth1),
        .vertex_depth2(context_depth2),
        .vertex_color0(context_color0), .vertex_color1(context_color1),
        .vertex_color2(context_color2),
        .fragment_valid(fragment_valid), .fragment_ready(fragment_ready),
        .fragment_x(fragment_x), .fragment_y(fragment_y),
        .fragment_primitive_id(fragment_primitive_id),
        .fragment_depth(fragment_depth), .fragment_color(fragment_color)
    );

    depth_test #(
        .PIXEL_WIDTH(PIXEL_WIDTH), .DEPTH_WIDTH(DEPTH_WIDTH),
        .COLOR_WIDTH(COLOR_WIDTH), .PRIMITIVE_ID_WIDTH(PRIMITIVE_ID_WIDTH),
        .FRAMEBUFFER_WIDTH(FRAMEBUFFER_WIDTH),
        .FRAMEBUFFER_HEIGHT(FRAMEBUFFER_HEIGHT)
    ) depth_stage (
        .clk(clk), .rst_n(rst_n),
        .fragment_valid(fragment_valid), .fragment_ready(fragment_ready),
        .fragment_x(fragment_x), .fragment_y(fragment_y),
        .fragment_primitive_id(fragment_primitive_id),
        .fragment_depth(fragment_depth), .fragment_color(fragment_color),
        .pixel_valid(pixel_valid), .pixel_ready(pixel_ready),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .pixel_primitive_id(pixel_primitive_id),
        .pixel_depth(pixel_depth), .pixel_color(pixel_color)
    );

    // The rasterizer owns one triangle at a time. Capture its setup record
    // when that record transfers so attributes stay aligned with all pixels
    // emitted by the scan.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            context_valid <= 1'b0;
            context_area <= '0;
            context_edge_a0 <= '0; context_edge_b0 <= '0; context_edge_c0 <= '0;
            context_edge_a1 <= '0; context_edge_b1 <= '0; context_edge_c1 <= '0;
            context_edge_a2 <= '0; context_edge_b2 <= '0; context_edge_c2 <= '0;
            context_depth0 <= '0; context_depth1 <= '0; context_depth2 <= '0;
            context_color0 <= '0; context_color1 <= '0; context_color2 <= '0;
        end else if (setup_out_valid && setup_out_ready && !setup_degenerate) begin
            context_valid <= 1'b1;
            context_area <= setup_area;
            context_edge_a0 <= setup_edge_a0; context_edge_b0 <= setup_edge_b0; context_edge_c0 <= setup_edge_c0;
            context_edge_a1 <= setup_edge_a1; context_edge_b1 <= setup_edge_b1; context_edge_c1 <= setup_edge_c1;
            context_edge_a2 <= setup_edge_a2; context_edge_b2 <= setup_edge_b2; context_edge_c2 <= setup_edge_c2;
            context_depth0 <= setup_depth0; context_depth1 <= setup_depth1; context_depth2 <= setup_depth2;
            context_color0 <= setup_color0; context_color1 <= setup_color1; context_color2 <= setup_color2;
        end
    end

endmodule
