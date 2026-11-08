`timescale 1ns/1ps

module apb_master
(
    input  logic        pclk,
    input  logic        presetn,
    output logic        psel,
    output logic        penable,
    output logic        pwrite,
    output logic [31:0] paddr,
    output logic [31:0] pwdata,
    input  logic [31:0] prdata,
    input  logic        pready,
    input  logic        pslverr
);

    parameter [31:0] BASE = 32'h7000_0000;
    localparam [31:0] OFF_STATE = 32'h00;
    localparam [31:0] OFF_CTRL  = 32'h04;

    logic [31:0] rdata;
    logic        last_slverr;
    int          errors = 0;

    task apb_write(input [31:0] addr, input [31:0] data);
        wait ((penable == 0) && (pready == 0));
        @(posedge pclk); #1;
        psel = 1'b1; paddr = addr; pwdata = data; pwrite = 1'b1;
        @(posedge pclk); #1;
        penable = 1'b1;
        @(posedge pclk);
        wait (pready == 1'b1);
        last_slverr = pslverr;
        @(posedge pclk); #1;
        psel = 1'b0; penable = 1'b0; pwrite = 1'b0;
        @(posedge pclk);
        $display("[MASTER] %t WRITE addr=0x%08h data=0x%08h slverr=%b", $time, addr, data, last_slverr);
    endtask

    task apb_read(input [31:0] addr, output logic [31:0] data);
        wait ((penable == 0) && (pready == 0));
        @(posedge pclk); #1;
        psel = 1'b1; pwrite = 1'b0; paddr = addr;
        @(posedge pclk); #1;
        penable = 1'b1;
        @(posedge pclk);
        wait (pready == 1'b1);
        last_slverr = pslverr;
        @(posedge pclk);
        data = prdata;
        #1;
        psel = 1'b0; penable = 1'b0;
        @(posedge pclk);
        $display("[MASTER] %t READ  addr=0x%08h data=0x%08h slverr=%b", $time, addr, data, last_slverr);
    endtask

    task check(input [31:0] got, input [31:0] expected, input [8*32-1:0] what);
        if (got === expected) $display("[CHECK ] PASS  %0s: 0x%08h", what, got);
        else begin
            $display("[CHECK ] FAIL  %0s: got 0x%08h, expected 0x%08h", what, got, expected);
            errors++;
        end
    endtask

    task test_reset_state;
        $display("--- test_reset_state ---");
        apb_read(BASE + OFF_STATE, rdata);
        check(rdata, 32'h00010001, "reset: A=Red B=Red");
    endtask

    initial begin
        psel = 0; penable = 0; pwrite = 0; paddr = 0; pwdata = 0;
        wait (presetn === 1'b1);
        repeat (5) @(posedge pclk);

        test_reset_state();

        repeat (10) @(posedge pclk);
        if (errors == 0) $display("[RESULT] ALL TESTS PASSED");
        else             $display("[RESULT] FAILED: %0d error(s)", errors);
        $finish;
    end
endmodule