// Backpressure-aware, single-pixel-per-iteration triangle rasterizer.
//
// The setup stage supplies a normalized triangle's clipped pixel bounds and
// edge equations. This stage walks the bounds in row-major order, emits only
// covered pixels, and holds an emitted pixel stable until pixel_ready.

module rasterizer #(
    parameter int COORD_WIDTH = 16,
    parameter int PIXEL_WIDTH = 6,
    parameter int COORD_FRAC_BITS = 4,
    parameter int PRIMITIVE_ID_WIDTH = 8,
    parameter int EDGE_WIDTH = 2*COORD_WIDTH + 2
) (
    input  logic clk,
    input  logic rst_n,

    input  logic setup_valid,
    output logic setup_ready,
    input  logic signed [COORD_WIDTH-1:0] setup_x_min,
    input  logic signed [COORD_WIDTH-1:0] setup_x_max,
    input  logic signed [COORD_WIDTH-1:0] setup_y_min,
    input  logic signed [COORD_WIDTH-1:0] setup_y_max,
    input  logic signed [COORD_WIDTH:0] setup_edge_a0,
    input  logic signed [COORD_WIDTH:0] setup_edge_b0,
    input  logic signed [EDGE_WIDTH-1:0] setup_edge_c0,
    input  logic signed [COORD_WIDTH:0] setup_edge_a1,
    input  logic signed [COORD_WIDTH:0] setup_edge_b1,
    input  logic signed [EDGE_WIDTH-1:0] setup_edge_c1,
    input  logic signed [COORD_WIDTH:0] setup_edge_a2,
    input  logic signed [COORD_WIDTH:0] setup_edge_b2,
    input  logic signed [EDGE_WIDTH-1:0] setup_edge_c2,
    input  logic [2:0] setup_top_left,
    input  logic [PRIMITIVE_ID_WIDTH-1:0] setup_primitive_id,

    output logic pixel_valid,
    input  logic pixel_ready,
    output logic [PIXEL_WIDTH-1:0] pixel_x,
    output logic [PIXEL_WIDTH-1:0] pixel_y,
    output logic [PRIMITIVE_ID_WIDTH-1:0] pixel_primitive_id
);

    localparam int EVAL_WIDTH = 2*COORD_WIDTH + 4;

    typedef enum logic [1:0] {IDLE, SCAN, OUTPUT} state_t;
    state_t state;

    logic signed [COORD_WIDTH-1:0] x_min_reg;
    logic signed [COORD_WIDTH-1:0] x_max_reg;
    logic signed [COORD_WIDTH-1:0] y_min_reg;
    logic signed [COORD_WIDTH-1:0] y_max_reg;
    logic signed [COORD_WIDTH-1:0] scan_x;
    logic signed [COORD_WIDTH-1:0] scan_y;
    logic signed [COORD_WIDTH:0] edge_a0_reg;
    logic signed [COORD_WIDTH:0] edge_b0_reg;
    logic signed [EDGE_WIDTH-1:0] edge_c0_reg;
    logic signed [COORD_WIDTH:0] edge_a1_reg;
    logic signed [COORD_WIDTH:0] edge_b1_reg;
    logic signed [EDGE_WIDTH-1:0] edge_c1_reg;
    logic signed [COORD_WIDTH:0] edge_a2_reg;
    logic signed [COORD_WIDTH:0] edge_b2_reg;
    logic signed [EDGE_WIDTH-1:0] edge_c2_reg;
    logic [2:0] top_left_reg;
    logic [PRIMITIVE_ID_WIDTH-1:0] primitive_id_reg;

    logic signed [COORD_WIDTH+1:0] pixel_center_x;
    logic signed [COORD_WIDTH+1:0] pixel_center_y;
    logic signed [EVAL_WIDTH-1:0] edge_value0;
    logic signed [EVAL_WIDTH-1:0] edge_value1;
    logic signed [EVAL_WIDTH-1:0] edge_value2;
    logic covered;
    logic last_pixel;
    logic last_in_row;

    assign setup_ready = (state == IDLE);

    always_comb begin
        pixel_center_x = (scan_x <<< COORD_FRAC_BITS) +
                         (1 <<< (COORD_FRAC_BITS - 1));
        pixel_center_y = (scan_y <<< COORD_FRAC_BITS) +
                         (1 <<< (COORD_FRAC_BITS - 1));

        edge_value0 = ($signed(edge_a0_reg) * $signed(pixel_center_x)) +
                      ($signed(edge_b0_reg) * $signed(pixel_center_y)) +
                      $signed(edge_c0_reg);
        edge_value1 = ($signed(edge_a1_reg) * $signed(pixel_center_x)) +
                      ($signed(edge_b1_reg) * $signed(pixel_center_y)) +
                      $signed(edge_c1_reg);
        edge_value2 = ($signed(edge_a2_reg) * $signed(pixel_center_x)) +
                      ($signed(edge_b2_reg) * $signed(pixel_center_y)) +
                      $signed(edge_c2_reg);

        covered = ((edge_value0 > 0) || ((edge_value0 == 0) && top_left_reg[0])) &&
                  ((edge_value1 > 0) || ((edge_value1 == 0) && top_left_reg[1])) &&
                  ((edge_value2 > 0) || ((edge_value2 == 0) && top_left_reg[2]));
        last_in_row = (scan_x == x_max_reg);
        last_pixel = last_in_row && (scan_y == y_max_reg);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pixel_valid <= 1'b0;
            pixel_x <= '0;
            pixel_y <= '0;
            pixel_primitive_id <= '0;
            x_min_reg <= '0;
            x_max_reg <= '0;
            y_min_reg <= '0;
            y_max_reg <= '0;
            scan_x <= '0;
            scan_y <= '0;
            edge_a0_reg <= '0;
            edge_b0_reg <= '0;
            edge_c0_reg <= '0;
            edge_a1_reg <= '0;
            edge_b1_reg <= '0;
            edge_c1_reg <= '0;
            edge_a2_reg <= '0;
            edge_b2_reg <= '0;
            edge_c2_reg <= '0;
            top_left_reg <= '0;
            primitive_id_reg <= '0;
        end else begin
            case (state)
                IDLE: begin
                    pixel_valid <= 1'b0;
                    if (setup_valid && setup_ready) begin
                        x_min_reg <= setup_x_min;
                        x_max_reg <= setup_x_max;
                        y_min_reg <= setup_y_min;
                        y_max_reg <= setup_y_max;
                        scan_x <= setup_x_min;
                        scan_y <= setup_y_min;
                        edge_a0_reg <= setup_edge_a0;
                        edge_b0_reg <= setup_edge_b0;
                        edge_c0_reg <= setup_edge_c0;
                        edge_a1_reg <= setup_edge_a1;
                        edge_b1_reg <= setup_edge_b1;
                        edge_c1_reg <= setup_edge_c1;
                        edge_a2_reg <= setup_edge_a2;
                        edge_b2_reg <= setup_edge_b2;
                        edge_c2_reg <= setup_edge_c2;
                        top_left_reg <= setup_top_left;
                        primitive_id_reg <= setup_primitive_id;
                        if ((setup_x_min <= setup_x_max) && (setup_y_min <= setup_y_max))
                            state <= SCAN;
                    end
                end

                SCAN: begin
                    if (covered) begin
                        pixel_valid <= 1'b1;
                        pixel_x <= scan_x[PIXEL_WIDTH-1:0];
                        pixel_y <= scan_y[PIXEL_WIDTH-1:0];
                        pixel_primitive_id <= primitive_id_reg;
                        state <= OUTPUT;
                    end else if (last_pixel) begin
                        state <= IDLE;
                    end else if (last_in_row) begin
                        scan_x <= x_min_reg;
                        scan_y <= scan_y + 1'b1;
                    end else begin
                        scan_x <= scan_x + 1'b1;
                    end
                end

                OUTPUT: begin
                    if (pixel_ready) begin
                        pixel_valid <= 1'b0;
                        if (last_pixel) begin
                            state <= IDLE;
                        end else if (last_in_row) begin
                            scan_x <= x_min_reg;
                            scan_y <= scan_y + 1'b1;
                            state <= SCAN;
                        end else begin
                            scan_x <= scan_x + 1'b1;
                            state <= SCAN;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

