#include <stdint.h>
#include "Vcordic2step.h"
#include "verilated.h"

// this is the function being emulated
int length_cordic(int16_t x, int16_t y, int16_t *x2_, int16_t y2) {
  int x2 = *x2_;
  if (x < 0) {  // start in right half-plane
    x = -x;
    x2 = -x2;
  }
  // two steps:
  int16_t step1x, step1y, step1x2, step1y2;
  if (y < 0) {
    int xp = x;
    step1x = x - y;
    step1y = y + x;
    step1x2 = x2 - y2;
    step1y2 = y2 + x2;
  } else {
    step1x = x + y;
    step1y = y - x;
    step1x2 = x2 + y2;
    step1y2 = y2 - x2;
  }
  int16_t step2x, step2x2;
  if (step1y < 0) {
    step2x = step1x - (step1y >> 1);
    step2x2 = step1x2 - (step1y2 >> 1);
  } else {
    step2x = step1x + (step1y >> 1);
    step2x2 = step1x2 + (step1y2 >> 1);
  }
  // divide by 0.625 as a cheap approximation to the 0.607 scaling factor factor
  // introduced by this algorithm (see https://en.wikipedia.org/wiki/CORDIC)

  // for 2 steps, the scaling factor is 0.6324555320336759 which is even closer
  // to this
  *x2_ = (step2x2 >> 1) + (step2x2 >> 3);
  return (step2x >> 1) + (step2x >> 3);
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  Vcordic2step *top = new Vcordic2step;

  top->xin = -11583;
  top->yin = 11583;
  top->x2in = 0;
  top->y2in = 16384;

  top->eval();

  // fetch results
  printf("verilated length: %d x2out: %d\n", top->length, top->x2out);

  int16_t x2_actual = 0, length_actual;
  length_actual = length_cordic(-11583, 11583, &x2_actual, 16384);
  printf("original  length: %d x2out: %d\n", length_actual, x2_actual);
}