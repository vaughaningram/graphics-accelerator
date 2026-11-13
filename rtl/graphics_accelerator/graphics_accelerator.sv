// Top-level geometry slice for the graphics accelerator.
//
// This module connects the registered triangle setup stage to the
// backpressure-aware rasterizer. It accepts one fixed-point triangle
// transaction and emits covered pixels with their primitive ID.

module graphics_accelerator #(
    parameter int COORD_WIDTH = 16,
    parameter int PIXEL_WIDTH = 6,
    parameter int COORD_FRAC_BITS = 4,
    parameter int PRIMITIVE_ID_WIDTH = 8,
    parameter int FRAMEBUFFER_WIDTH = 64,
    parameter int FRAMEBUFFER_HEIGHT = 64,
    parameter int EDGE_WIDTH = 2*COORD_WIDTH + 2
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
    input logic [PRIMITIVE_ID_WIDTH-1:0] triangle_primitive_id,

    output logic pixel_valid,
    input logic pixel_ready,
    output logic [PIXEL_WIDTH-1:0] pixel_x,
    output logic [PIXEL_WIDTH-1:0] pixel_y,
    output logic [PRIMITIVE_ID_WIDTH-1:0] pixel_primitive_id
);

    logic setup_in_ready;
    logic setup_out_valid;
    logic setup_out_ready;
    logic setup_degenerate;
    logic signed [COORD_WIDTH-1:0] setup_x_min;
    logic signed [COORD_WIDTH-1:0] setup_x_max;
    logic signed [COORD_WIDTH-1:0] setup_y_min;
    logic signed [COORD_WIDTH-1:0] setup_y_max;
    logic signed [COORD_WIDTH:0] setup_edge_a0;
    logic signed [COORD_WIDTH:0] setup_edge_b0;
    logic signed [EDGE_WIDTH-1:0] setup_edge_c0;
    logic signed [COORD_WIDTH:0] setup_edge_a1;
    logic signed [COORD_WIDTH:0] setup_edge_b1;
    logic signed [EDGE_WIDTH-1:0] setup_edge_c1;
    logic signed [COORD_WIDTH:0] setup_edge_a2;
    logic signed [COORD_WIDTH:0] setup_edge_b2;
    logic signed [EDGE_WIDTH-1:0] setup_edge_c2;
    logic [2:0] setup_top_left;
    logic [PRIMITIVE_ID_WIDTH-1:0] setup_primitive_id;

    logic raster_setup_valid;
    logic raster_setup_ready;

    assign triangle_ready = setup_in_ready;

    // A degenerate triangle is consumed by the setup stage but never enters
    // the rasterizer. Non-degenerate setup records transfer normally.
    assign setup_out_ready = raster_setup_ready;
    assign raster_setup_valid = setup_out_valid && !setup_degenerate;

    triangle_setup #(
        .COORD_WIDTH(COORD_WIDTH),
        .PRIMITIVE_ID_WIDTH(PRIMITIVE_ID_WIDTH),
        .COORD_FRAC_BITS(COORD_FRAC_BITS),
        .FRAMEBUFFER_WIDTH(FRAMEBUFFER_WIDTH),
        .FRAMEBUFFER_HEIGHT(FRAMEBUFFER_HEIGHT),
        .EDGE_WIDTH(EDGE_WIDTH)
    ) setup_stage (
        .clk(clk),
        .rst_n(rst_n),
        .in_valid(triangle_valid),
        .in_ready(setup_in_ready),
        .in_x0(triangle_x0),
        .in_y0(triangle_y0),
        .in_x1(triangle_x1),
        .in_y1(triangle_y1),
        .in_x2(triangle_x2),
        .in_y2(triangle_y2),
        .in_primitive_id(triangle_primitive_id),
        .out_valid(setup_out_valid),
        .out_ready(setup_out_ready),
        .out_x0(),
        .out_y0(),
        .out_x1(),
        .out_y1(),
        .out_x2(),
        .out_y2(),
        .out_primitive_id(setup_primitive_id),
        .out_area(),
        .out_degenerate(setup_degenerate),
        .out_x_min(setup_x_min),
        .out_x_max(setup_x_max),
        .out_y_min(setup_y_min),
        .out_y_max(setup_y_max),
        .out_edge_a0(setup_edge_a0),
        .out_edge_b0(setup_edge_b0),
        .out_edge_c0(setup_edge_c0),
        .out_edge_a1(setup_edge_a1),
        .out_edge_b1(setup_edge_b1),
        .out_edge_c1(setup_edge_c1),
        .out_edge_a2(setup_edge_a2),
        .out_edge_b2(setup_edge_b2),
        .out_edge_c2(setup_edge_c2),
        .out_top_left(setup_top_left)
    );

    rasterizer #(
        .COORD_WIDTH(COORD_WIDTH),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .COORD_FRAC_BITS(COORD_FRAC_BITS),
        .PRIMITIVE_ID_WIDTH(PRIMITIVE_ID_WIDTH),
        .EDGE_WIDTH(EDGE_WIDTH)
    ) rasterizer_stage (
        .clk(clk),
        .rst_n(rst_n),
        .setup_valid(raster_setup_valid),
        .setup_ready(raster_setup_ready),
        .setup_x_min(setup_x_min),
        .setup_x_max(setup_x_max),
        .setup_y_min(setup_y_min),
        .setup_y_max(setup_y_max),
        .setup_edge_a0(setup_edge_a0),
        .setup_edge_b0(setup_edge_b0),
        .setup_edge_c0(setup_edge_c0),
        .setup_edge_a1(setup_edge_a1),
        .setup_edge_b1(setup_edge_b1),
        .setup_edge_c1(setup_edge_c1),
        .setup_edge_a2(setup_edge_a2),
        .setup_edge_b2(setup_edge_b2),
        .setup_edge_c2(setup_edge_c2),
        .setup_top_left(setup_top_left),
        .setup_primitive_id(setup_primitive_id),
        .pixel_valid(pixel_valid),
        .pixel_ready(pixel_ready),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_primitive_id(pixel_primitive_id)
    );

endmodule

