// ---------------------- D FLIP-FLOP DESIGN -------------------------
module d_ff (
    input clock,
    input reset,       
    input data_in,
    output reg data_out
);

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            data_out <= 1'b0;  
        end else begin
            data_out <= data_in;  
        end
    end
endmodule

// ---------------------- DFF INTERFACE -------------------------
interface dff_interface();
    logic clock;
    logic reset;
    logic data_in;
    logic data_out;
endinterface