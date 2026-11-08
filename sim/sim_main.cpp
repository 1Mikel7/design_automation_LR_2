#include <memory>
#include "verilated.h"
#include "verilated_cov.h"
#include "Vtop.h"

int main(int argc, char** argv) {
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};
    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);
    const std::unique_ptr<Vtop> topp{new Vtop{contextp.get()}};
    while (!contextp->gotFinish()) {
        topp->eval();
        if (!topp->eventsPending()) break;
        contextp->time(topp->nextTimeSlot());
    }
    topp->final();
    contextp->coveragep()->write("coverage.dat");
    return 0;
}