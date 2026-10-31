// Triangle setup front end for the graphics accelerator.
//
// This first stage accepts one triangle transaction, normalizes its winding,
// and reports the positive magnitude of twice its signed area. Degenerate
// triangles are passed through with degenerate=1 so downstream control can
// discard them deterministically.

module triangle_setup #(
    parameter int COORD_WIDTH = 16,
    parameter int PRIMITIVE_ID_WIDTH = 8,
    parameter int COORD_FRAC_BITS = 4,
    parameter int FRAMEBUFFER_WIDTH = 64,
    parameter int FRAMEBUFFER_HEIGHT = 64
) (
    input  logic clk,
    input  logic rst_n,

    input  logic in_valid,
    output logic in_ready,
    input  logic signed [COORD_WIDTH-1:0] in_x0,
    input  logic signed [COORD_WIDTH-1:0] in_y0,
    input  logic signed [COORD_WIDTH-1:0] in_x1,
    input  logic signed [COORD_WIDTH-1:0] in_y1,
    input  logic signed [COORD_WIDTH-1:0] in_x2,
    input  logic signed [COORD_WIDTH-1:0] in_y2,
    input  logic [PRIMITIVE_ID_WIDTH-1:0] in_primitive_id,

    output logic out_valid,
    input  logic out_ready,
    output logic signed [COORD_WIDTH-1:0] out_x0,
    output logic signed [COORD_WIDTH-1:0] out_y0,
    output logic signed [COORD_WIDTH-1:0] out_x1,
    output logic signed [COORD_WIDTH-1:0] out_y1,
    output logic signed [COORD_WIDTH-1:0] out_x2,
    output logic signed [COORD_WIDTH-1:0] out_y2,
    output logic [PRIMITIVE_ID_WIDTH-1:0] out_primitive_id,
    output logic signed [2*COORD_WIDTH+1:0] out_area,
    output logic out_degenerate,
    output logic signed [COORD_WIDTH-1:0] out_x_min,
    output logic signed [COORD_WIDTH-1:0] out_x_max,
    output logic signed [COORD_WIDTH-1:0] out_y_min,
    output logic signed [COORD_WIDTH-1:0] out_y_max
);

    localparam int AREA_WIDTH = 2*COORD_WIDTH + 2;

    logic signed [COORD_WIDTH:0] dx01;
    logic signed [COORD_WIDTH:0] dy01;
    logic signed [COORD_WIDTH:0] dx02;
    logic signed [COORD_WIDTH:0] dy02;
    logic signed [AREA_WIDTH-1:0] term_a;
    logic signed [AREA_WIDTH-1:0] term_b;
    logic signed [AREA_WIDTH-1:0] area_calc;
    logic signed [AREA_WIDTH-1:0] area_abs;
    logic signed [COORD_WIDTH:0] min_x_raw;
    logic signed [COORD_WIDTH:0] max_x_raw;
    logic signed [COORD_WIDTH:0] min_y_raw;
    logic signed [COORD_WIDTH:0] max_y_raw;
    logic signed [COORD_WIDTH+1:0] min_x_adjusted;
    logic signed [COORD_WIDTH+1:0] max_x_adjusted;
    logic signed [COORD_WIDTH+1:0] min_y_adjusted;
    logic signed [COORD_WIDTH+1:0] max_y_adjusted;
    logic signed [COORD_WIDTH-1:0] x_min_calc;
    logic signed [COORD_WIDTH-1:0] x_max_calc;
    logic signed [COORD_WIDTH-1:0] y_min_calc;
    logic signed [COORD_WIDTH-1:0] y_max_calc;

    function automatic logic signed [COORD_WIDTH-1:0] clamp_x(
        input logic signed [COORD_WIDTH+1:0] value
    );
        if (value < 0)
            clamp_x = '0;
        else if (value >= FRAMEBUFFER_WIDTH)
            clamp_x = FRAMEBUFFER_WIDTH - 1;
        else
            clamp_x = value[COORD_WIDTH-1:0];
    endfunction

    function automatic logic signed [COORD_WIDTH-1:0] clamp_y(
        input logic signed [COORD_WIDTH+1:0] value
    );
        if (value < 0)
            clamp_y = '0;
        else if (value >= FRAMEBUFFER_HEIGHT)
            clamp_y = FRAMEBUFFER_HEIGHT - 1;
        else
            clamp_y = value[COORD_WIDTH-1:0];
    endfunction

    assign in_ready = ~out_valid | out_ready;

    always_comb begin
        dx01 = $signed(in_x1) - $signed(in_x0);
        dy01 = $signed(in_y1) - $signed(in_y0);
        dx02 = $signed(in_x2) - $signed(in_x0);
        dy02 = $signed(in_y2) - $signed(in_y0);

        term_a = dx01 * dy02;
        term_b = dy01 * dx02;
        area_calc = term_a - term_b;
        area_abs = (area_calc < 0) ? -area_calc : area_calc;

        min_x_raw = (in_x0 < in_x1) ? ((in_x0 < in_x2) ? in_x0 : in_x2) :
                                      ((in_x1 < in_x2) ? in_x1 : in_x2);
        max_x_raw = (in_x0 > in_x1) ? ((in_x0 > in_x2) ? in_x0 : in_x2) :
                                      ((in_x1 > in_x2) ? in_x1 : in_x2);
        min_y_raw = (in_y0 < in_y1) ? ((in_y0 < in_y2) ? in_y0 : in_y2) :
                                      ((in_y1 < in_y2) ? in_y1 : in_y2);
        max_y_raw = (in_y0 > in_y1) ? ((in_y0 > in_y2) ? in_y0 : in_y2) :
                                      ((in_y1 > in_y2) ? in_y1 : in_y2);

        // Pixel centers are represented by raw coordinate + 2^(frac_bits-1).
        // The lower bound uses an arithmetic ceiling; the upper bound uses
        // an arithmetic floor, matching the Python setup model.
        min_x_adjusted = min_x_raw - (1 <<< (COORD_FRAC_BITS - 1)) +
                         ((1 <<< COORD_FRAC_BITS) - 1);
        max_x_adjusted = max_x_raw - (1 <<< (COORD_FRAC_BITS - 1));
        min_y_adjusted = min_y_raw - (1 <<< (COORD_FRAC_BITS - 1)) +
                         ((1 <<< COORD_FRAC_BITS) - 1);
        max_y_adjusted = max_y_raw - (1 <<< (COORD_FRAC_BITS - 1));
        x_min_calc = clamp_x(min_x_adjusted >>> COORD_FRAC_BITS);
        x_max_calc = clamp_x(max_x_adjusted >>> COORD_FRAC_BITS);
        y_min_calc = clamp_y(min_y_adjusted >>> COORD_FRAC_BITS);
        y_max_calc = clamp_y(max_y_adjusted >>> COORD_FRAC_BITS);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_x0 <= '0;
            out_y0 <= '0;
            out_x1 <= '0;
            out_y1 <= '0;
            out_x2 <= '0;
            out_y2 <= '0;
            out_primitive_id <= '0;
            out_area <= '0;
            out_degenerate <= 1'b0;
            out_x_min <= '0;
            out_x_max <= '0;
            out_y_min <= '0;
            out_y_max <= '0;
        end else if (in_valid && in_ready) begin
            out_valid <= 1'b1;
            out_x0 <= in_x0;
            out_y0 <= in_y0;
            out_primitive_id <= in_primitive_id;
            out_degenerate <= (area_calc == 0);
            out_area <= area_abs;
            out_x_min <= x_min_calc;
            out_x_max <= x_max_calc;
            out_y_min <= y_min_calc;
            out_y_max <= y_max_calc;

            if (area_calc < 0) begin
                out_x1 <= in_x2;
                out_y1 <= in_y2;
                out_x2 <= in_x1;
                out_y2 <= in_y1;
            end else begin
                out_x1 <= in_x1;
                out_y1 <= in_y1;
                out_x2 <= in_x2;
                out_y2 <= in_y2;
            end
        end else if (out_valid && out_ready) begin
            out_valid <= 1'b0;
        end
    end

endmodule

