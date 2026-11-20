// Bounded depth test for the full beta pipeline.
//
// This first implementation models a 64x64 depth buffer as synthesizable
// register storage. A fragment passes when its unsigned depth is nearer than
// the stored value. Passing fragments update the buffer and continue through
// the ready/valid output stream; failing fragments are consumed silently.

module depth_test #(
    parameter int PIXEL_WIDTH = 6,
    parameter int DEPTH_WIDTH = 16,
    parameter int COLOR_WIDTH = 8,
    parameter int PRIMITIVE_ID_WIDTH = 8,
    parameter int FRAMEBUFFER_WIDTH = 64,
    parameter int FRAMEBUFFER_HEIGHT = 64
) (
    input logic clk,
    input logic rst_n,

    input logic fragment_valid,
    output logic fragment_ready,
    input logic [PIXEL_WIDTH-1:0] fragment_x,
    input logic [PIXEL_WIDTH-1:0] fragment_y,
    input logic [PRIMITIVE_ID_WIDTH-1:0] fragment_primitive_id,
    input logic [DEPTH_WIDTH-1:0] fragment_depth,
    input logic [4*COLOR_WIDTH-1:0] fragment_color,

    output logic pixel_valid,
    input logic pixel_ready,
    output logic [PIXEL_WIDTH-1:0] pixel_x,
    output logic [PIXEL_WIDTH-1:0] pixel_y,
    output logic [PRIMITIVE_ID_WIDTH-1:0] pixel_primitive_id,
    output logic [DEPTH_WIDTH-1:0] pixel_depth,
    output logic [4*COLOR_WIDTH-1:0] pixel_color
);

    localparam int BUFFER_ENTRIES = FRAMEBUFFER_WIDTH * FRAMEBUFFER_HEIGHT;

    logic [DEPTH_WIDTH-1:0] depth_buffer [0:BUFFER_ENTRIES-1];
    integer reset_index;
    integer depth_index;

    assign fragment_ready = ~pixel_valid | pixel_ready;

    always @* begin
        depth_index = fragment_y * FRAMEBUFFER_WIDTH + fragment_x;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_valid <= 1'b0;
            pixel_x <= '0;
            pixel_y <= '0;
            pixel_primitive_id <= '0;
            pixel_depth <= '0;
            pixel_color <= '0;
            for (reset_index = 0; reset_index < BUFFER_ENTRIES; reset_index = reset_index + 1)
                depth_buffer[reset_index] <= {DEPTH_WIDTH{1'b1}};
        end else if (fragment_valid && fragment_ready) begin
            if (fragment_depth < depth_buffer[depth_index]) begin
                depth_buffer[depth_index] <= fragment_depth;
                pixel_valid <= 1'b1;
                pixel_x <= fragment_x;
                pixel_y <= fragment_y;
                pixel_primitive_id <= fragment_primitive_id;
                pixel_depth <= fragment_depth;
                pixel_color <= fragment_color;
            end else begin
                pixel_valid <= 1'b0;
            end
        end else if (pixel_valid && pixel_ready) begin
            pixel_valid <= 1'b0;
        end
    end

endmodule
