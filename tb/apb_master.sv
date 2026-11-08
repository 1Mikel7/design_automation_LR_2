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

    function automatic [31:0] expected_state(input int n);
        case (n)
            0: expected_state = 32'h00010001;
            1: expected_state = 32'h00010003;
            2: expected_state = 32'h00010004;
            3: expected_state = 32'h00010002;
            4: expected_state = 32'h00030001;
            5: expected_state = 32'h00040001;
            6: expected_state = 32'h00020001;
            default: expected_state = 32'hDEADBEEF;
        endcase
    endfunction

    task test_full_cycle;
        int n;
        $display("--- test_full_cycle ---");
        for (n = 0; n < 14; n++) begin
            apb_read (BASE + OFF_STATE, rdata);
            check(rdata, expected_state(n % 7), "state in cycle");
            apb_write(BASE + OFF_CTRL, 32'h1);
        end
    endtask

    task test_one_step;
        $display("--- test_one_step ---");
        apb_write(BASE + OFF_CTRL, 32'h1);
        apb_read (BASE + OFF_STATE, rdata);
        check(rdata, 32'h00010003, "after NEXT: A=Red+Yellow B=Red");
    endtask

    task test_errors;
        logic [31:0] saved_state;
        $display("--- test_errors ---");
        apb_read(BASE + OFF_STATE, saved_state);
        apb_write(BASE + OFF_STATE, 32'hFFFF_FFFF);
        check({31'b0, last_slverr}, 32'h1, "write STATE -> PSLVERR");
        apb_write(BASE + 32'h08, 32'h1);
        check({31'b0, last_slverr}, 32'h1, "write bad addr -> PSLVERR");
        apb_read(BASE + 32'h08, rdata);
        check({31'b0, last_slverr}, 32'h1, "read bad addr -> PSLVERR");
        apb_read(BASE + OFF_STATE, rdata);
        check(rdata, saved_state, "state not changed by errors");
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

        test_full_cycle();
        test_reset_state();
        test_one_step();
        test_errors();

        repeat (10) @(posedge pclk);
        if (errors == 0) $display("[RESULT] ALL TESTS PASSED");
        else             $display("[RESULT] FAILED: %0d error(s)", errors);
        $finish;
    end
endmodule