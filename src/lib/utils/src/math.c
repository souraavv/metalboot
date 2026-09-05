#include "math.h"

uint16_t min(uint16_t a, uint16_t b) {
    return a < b ? a : b;
}

uint16_t max(uint16_t a, uint16_t b) {
    return a > b ? a : b;
}

uint16_t divCeil(uint16_t a, uint16_t b) {
    return (a + b - 1) / b;
}

bool isEven(uint16_t a) {
    return (a & 1) == 0;
}

bool isOdd(uint16_t a) {
    return (a & 1) != 0;
}
