`timescale 1ns/1ps

module apb_traffic_light
(
    input  logic        pclk, presetn,
    input  logic [31:0] paddr, pwdata,
    input  logic        psel, penable, pwrite,
    output logic        pready, pslverr,
    output logic [31:0] prdata
);

    enum logic [1:0] { APB_SETUP, APB_W_ENABLE, APB_R_ENABLE } apb_st;

    always @(posedge pclk)
    if (!presetn) begin
        prdata  <= '0; pslverr <= 1'b0; pready <= 1'b0;
        apb_st  <= APB_SETUP;
    end else begin
        case (apb_st)
            APB_SETUP: begin
                prdata <= '0; pready <= 1'b0; pslverr <= 1'b0;
                if (psel && !penable) begin
                    if (pwrite) apb_st <= APB_W_ENABLE;
                    else        apb_st <= APB_R_ENABLE;
                end
            end
            APB_W_ENABLE: begin
                if (psel && penable && pwrite) begin
                    pready <= 1'b1; apb_st <= APB_SETUP;
                end
            end
            APB_R_ENABLE: begin
                if (psel && penable && !pwrite) begin
                    pready <= 1'b1; prdata <= 32'h0; apb_st <= APB_SETUP;
                end
            end
            default: begin pslverr <= 1'b1; apb_st <= APB_SETUP; end
        endcase
    end
endmodule