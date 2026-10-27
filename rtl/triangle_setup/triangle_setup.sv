// Triangle setup front end for the graphics accelerator.
//
// This first stage accepts one triangle transaction, normalizes its winding,
// and reports the positive magnitude of twice its signed area. Degenerate
// triangles are passed through with degenerate=1 so downstream control can
// discard them deterministically.

module triangle_setup #(
    parameter int COORD_WIDTH = 16,
    parameter int PRIMITIVE_ID_WIDTH = 8
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
    output logic out_degenerate
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
        end else if (in_valid && in_ready) begin
            out_valid <= 1'b1;
            out_x0 <= in_x0;
            out_y0 <= in_y0;
            out_primitive_id <= in_primitive_id;
            out_degenerate <= (area_calc == 0);
            out_area <= area_abs;

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

