// Barycentric fragment interpolator for the limited-scope beta pipeline.
//
// The rasterizer has already accepted a covered pixel. This stage evaluates
// the three edge functions at that pixel center and uses their normalized
// weights to produce depth and packed RGBA values. Division is intentionally
// kept as a straightforward integer operation for the first synthesizable
// reference implementation; a later performance study can replace it with
// reciprocal/multiply hardware.

module fragment_interpolator #(
    parameter int COORD_WIDTH = 16,
    parameter int PIXEL_WIDTH = 6,
    parameter int COORD_FRAC_BITS = 4,
    parameter int PRIMITIVE_ID_WIDTH = 8,
    parameter int EDGE_WIDTH = 2*COORD_WIDTH + 2,
    parameter int DEPTH_WIDTH = 16,
    parameter int COLOR_WIDTH = 8
) (
    input logic clk,
    input logic rst_n,

    input logic pixel_valid,
    output logic pixel_ready,
    input logic [PIXEL_WIDTH-1:0] pixel_x,
    input logic [PIXEL_WIDTH-1:0] pixel_y,
    input logic [PRIMITIVE_ID_WIDTH-1:0] pixel_primitive_id,

    input logic signed [EDGE_WIDTH-1:0] triangle_area,
    input logic signed [COORD_WIDTH:0] edge_a0,
    input logic signed [COORD_WIDTH:0] edge_b0,
    input logic signed [EDGE_WIDTH-1:0] edge_c0,
    input logic signed [COORD_WIDTH:0] edge_a1,
    input logic signed [COORD_WIDTH:0] edge_b1,
    input logic signed [EDGE_WIDTH-1:0] edge_c1,
    input logic signed [COORD_WIDTH:0] edge_a2,
    input logic signed [COORD_WIDTH:0] edge_b2,
    input logic signed [EDGE_WIDTH-1:0] edge_c2,
    input logic [DEPTH_WIDTH-1:0] vertex_depth0,
    input logic [DEPTH_WIDTH-1:0] vertex_depth1,
    input logic [DEPTH_WIDTH-1:0] vertex_depth2,
    input logic [4*COLOR_WIDTH-1:0] vertex_color0,
    input logic [4*COLOR_WIDTH-1:0] vertex_color1,
    input logic [4*COLOR_WIDTH-1:0] vertex_color2,

    output logic fragment_valid,
    input logic fragment_ready,
    output logic [PIXEL_WIDTH-1:0] fragment_x,
    output logic [PIXEL_WIDTH-1:0] fragment_y,
    output logic [PRIMITIVE_ID_WIDTH-1:0] fragment_primitive_id,
    output logic [DEPTH_WIDTH-1:0] fragment_depth,
    output logic [4*COLOR_WIDTH-1:0] fragment_color
);

    localparam int EVAL_WIDTH = 2*COORD_WIDTH + 5;
    localparam int ATTR_ACCUM_WIDTH = EVAL_WIDTH + DEPTH_WIDTH + 2;

    logic signed [COORD_WIDTH+1:0] sample_x;
    logic signed [COORD_WIDTH+1:0] sample_y;
    logic signed [EVAL_WIDTH-1:0] edge_value0;
    logic signed [EVAL_WIDTH-1:0] edge_value1;
    logic signed [EVAL_WIDTH-1:0] edge_value2;
    logic [DEPTH_WIDTH-1:0] depth_calc;
    logic [4*COLOR_WIDTH-1:0] color_calc;

    wire [COLOR_WIDTH-1:0] color0_r = vertex_color0[4*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color0_g = vertex_color0[3*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color0_b = vertex_color0[2*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color0_a = vertex_color0[COLOR_WIDTH-1:0];
    wire [COLOR_WIDTH-1:0] color1_r = vertex_color1[4*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color1_g = vertex_color1[3*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color1_b = vertex_color1[2*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color1_a = vertex_color1[COLOR_WIDTH-1:0];
    wire [COLOR_WIDTH-1:0] color2_r = vertex_color2[4*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color2_g = vertex_color2[3*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color2_b = vertex_color2[2*COLOR_WIDTH-1 -: COLOR_WIDTH];
    wire [COLOR_WIDTH-1:0] color2_a = vertex_color2[COLOR_WIDTH-1:0];

    assign pixel_ready = ~fragment_valid | fragment_ready;

    always @* begin
        sample_x = ($signed({1'b0, pixel_x}) <<< COORD_FRAC_BITS) +
                   (1 <<< (COORD_FRAC_BITS - 1));
        sample_y = ($signed({1'b0, pixel_y}) <<< COORD_FRAC_BITS) +
                   (1 <<< (COORD_FRAC_BITS - 1));
        edge_value0 = ($signed(edge_a0) * $signed(sample_x)) +
                      ($signed(edge_b0) * $signed(sample_y)) + $signed(edge_c0);
        edge_value1 = ($signed(edge_a1) * $signed(sample_x)) +
                      ($signed(edge_b1) * $signed(sample_y)) + $signed(edge_c1);
        edge_value2 = ($signed(edge_a2) * $signed(sample_x)) +
                      ($signed(edge_b2) * $signed(sample_y)) + $signed(edge_c2);
        depth_calc = interpolate_depth(vertex_depth0, vertex_depth1, vertex_depth2);
        color_calc = {
            interpolate_channel(color0_r, color1_r, color2_r),
            interpolate_channel(color0_g, color1_g, color2_g),
            interpolate_channel(color0_b, color1_b, color2_b),
            interpolate_channel(color0_a, color1_a, color2_a)
        };
    end

    function automatic logic [DEPTH_WIDTH-1:0] interpolate_depth(
        input logic [DEPTH_WIDTH-1:0] value0,
        input logic [DEPTH_WIDTH-1:0] value1,
        input logic [DEPTH_WIDTH-1:0] value2
    );
        logic signed [ATTR_ACCUM_WIDTH-1:0] product0;
        logic signed [ATTR_ACCUM_WIDTH-1:0] product1;
        logic signed [ATTR_ACCUM_WIDTH-1:0] product2;
        logic signed [ATTR_ACCUM_WIDTH-1:0] numerator;
        logic signed [ATTR_ACCUM_WIDTH-1:0] quotient;
        begin
            product0 = $signed(edge_value1) * $signed({1'b0, value0});
            product1 = $signed(edge_value2) * $signed({1'b0, value1});
            product2 = $signed(edge_value0) * $signed({1'b0, value2});
            numerator = product0 + product1 + product2;
            if (triangle_area == 0)
                interpolate_depth = '0;
            else begin
                quotient = numerator / $signed(triangle_area);
                if (quotient < 0)
                    interpolate_depth = '0;
                else if (quotient > ((1 <<< DEPTH_WIDTH) - 1))
                    interpolate_depth = {DEPTH_WIDTH{1'b1}};
                else
                    interpolate_depth = quotient[DEPTH_WIDTH-1:0];
            end
        end
    endfunction

    function automatic logic [COLOR_WIDTH-1:0] interpolate_channel(
        input logic [COLOR_WIDTH-1:0] value0,
        input logic [COLOR_WIDTH-1:0] value1,
        input logic [COLOR_WIDTH-1:0] value2
    );
        logic signed [ATTR_ACCUM_WIDTH-1:0] product0;
        logic signed [ATTR_ACCUM_WIDTH-1:0] product1;
        logic signed [ATTR_ACCUM_WIDTH-1:0] product2;
        logic signed [ATTR_ACCUM_WIDTH-1:0] numerator;
        logic signed [ATTR_ACCUM_WIDTH-1:0] quotient;
        begin
            product0 = $signed(edge_value1) * $signed({1'b0, value0});
            product1 = $signed(edge_value2) * $signed({1'b0, value1});
            product2 = $signed(edge_value0) * $signed({1'b0, value2});
            numerator = product0 + product1 + product2;
            if (triangle_area == 0)
                interpolate_channel = '0;
            else begin
                quotient = numerator / $signed(triangle_area);
                if (quotient < 0)
                    interpolate_channel = '0;
                else if (quotient > ((1 <<< COLOR_WIDTH) - 1))
                    interpolate_channel = {COLOR_WIDTH{1'b1}};
                else
                    interpolate_channel = quotient[COLOR_WIDTH-1:0];
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fragment_valid <= 1'b0;
            fragment_x <= '0;
            fragment_y <= '0;
            fragment_primitive_id <= '0;
            fragment_depth <= '0;
            fragment_color <= '0;
        end else if (pixel_valid && pixel_ready) begin
            fragment_valid <= 1'b1;
            fragment_x <= pixel_x;
            fragment_y <= pixel_y;
            fragment_primitive_id <= pixel_primitive_id;
            fragment_depth <= depth_calc;
            fragment_color <= color_calc;
        end else if (fragment_valid && fragment_ready) begin
            fragment_valid <= 1'b0;
        end
    end

endmodule
