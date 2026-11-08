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
    localparam [7:0] ADDR_STATE = 8'h00;
    localparam [7:0] ADDR_CTRL  = 8'h04;

    localparam [15:0] R  = 16'h0001;
    localparam [15:0] RY = 16'h0003;
    localparam [15:0] G  = 16'h0004;
    localparam [15:0] Y  = 16'h0002;

    logic [2:0]  phase;
    logic [31:0] lamps;
    logic [2:0] next_phase;

    always_comb begin
        case (phase)
            3'd0:    lamps = {R,  R }; // A=R, B=R
            3'd1:    lamps = {R,  RY}; // A=RY, B=R
            3'd2:    lamps = {R,  G }; // A=G, B=R
            3'd3:    lamps = {R,  Y }; // A=Y, B=R
            3'd4:    lamps = {RY, R }; // A=R, B=RY
            3'd5:    lamps = {G,  R }; // A=R, B=G
            3'd6:    lamps = {Y,  R }; // A=R, B=Y
            // verilator coverage_off
            default: lamps = {R,  R };
            // verilator coverage_on

        endcase
    end

    always_comb begin
        if (phase == 3'd6) next_phase = 3'd0;
        else               next_phase = phase + 3'd1;
    end

    always @(posedge pclk)
    if (!presetn) begin
        prdata  <= '0; pslverr <= 1'b0; pready <= 1'b0;
        phase   <= 3'd0;
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
                                        pready <= 1'b1;
                    case (paddr[7:0])
                        ADDR_CTRL: begin
                            if (pwdata[0]) begin
                                phase <= next_phase;
                                $display("[DUT   ] %t CTRL  NEXT: phase %0d -> %0d", $time, phase, next_phase);
                            end
                        end
                        ADDR_STATE: begin
                            pslverr <= 1'b1;
                            $display("[DUT   ] %t WRITE to read-only STATE -> PSLVERR", $time);
                        end
                        default: begin
                            pslverr <= 1'b1;
                            $display("[DUT   ] %t WRITE to bad addr -> PSLVERR", $time);
                        end
                    endcase
                    apb_st <= APB_SETUP;
                end
            end
            APB_R_ENABLE: begin
                if (psel && penable && !pwrite) begin
                    pready <= 1'b1;
                    case (paddr[7:0])
                        ADDR_STATE: begin
                            prdata <= lamps;
                            $display("[DUT   ] %t READ  STATE = 0x%08h (phase %0d)", $time, lamps, phase);
                        end
                        ADDR_CTRL:  prdata <= 32'h0;
                        default: begin
                            pslverr <= 1'b1;
                            $display("[DUT   ] %t READ  bad addr -> PSLVERR", $time);
                        end
                    endcase
                    apb_st <= APB_SETUP;
                end
            end
            // verilator coverage_off
            default: begin pslverr <= 1'b1; apb_st <= APB_SETUP; end
            // verilator coverage_on
        endcase
    end
endmodule