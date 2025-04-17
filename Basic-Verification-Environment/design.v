module d_ff (
    input  logic clock,
    input  logic reset,
    input  logic data_in,
    output reg   data_out
);
    always @(posedge clock) begin
        if (reset) begin
            data_out <= 1'b0;
        end
        else begin
            data_out <= data_in;
        end
    end
endmodule: d_ff

interface dff_interface;
    logic clock;
    logic reset;
    logic data_in;
    logic data_out;
endinterface: dff_interface