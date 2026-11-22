#define UART_TX (*(volatile char *)0x10000000)
static inline unsigned rdcycle(void) { unsigned c; __asm__ volatile ("csrr %0, cycle" : "=r"(c)); return c; }
static void putc_(char c) { UART_TX = c; }
static void puts_(const char *s) { while (*s) putc_(*s++); }
static void putdec(unsigned v) {
    static const unsigned p10[10] = {1000000000u,100000000u,10000000u,1000000u,100000u,10000u,1000u,100u,10u,1u};
    int started = 0;
    for (int i = 0; i < 10; i++) { unsigned d = 0; while (v >= p10[i]) { v -= p10[i]; d++; }
        if (d || started || i == 9) { putc_((char)('0' + d)); started = 1; } }
}
static void putsig(int v) { if (v < 0) { putc_('-'); putdec((unsigned)(-v)); } else putdec((unsigned)v); }
int main(void) {
    unsigned pa = 0x04030201u, pb = 0x08070605u;
    int c0, c1, c2, c3;
    unsigned t0 = rdcycle();
    __asm__ volatile (".insn r 0x0b, 0, 0, %0, %1, %2" : "=r"(c0) : "r"(pa), "r"(pb));
    unsigned t1 = rdcycle();
    __asm__ volatile (".insn r 0x0b, 1, 1, %0, x0, x0" : "=r"(c1));
    __asm__ volatile (".insn r 0x0b, 1, 2, %0, x0, x0" : "=r"(c2));
    __asm__ volatile (".insn r 0x0b, 1, 3, %0, x0, x0" : "=r"(c3));
    unsigned t2 = rdcycle();
    puts_("XMAT S1 run="); putdec(t1 - t0); puts_(" all="); putdec(t2 - t0); puts_(" c=");
    putsig(c0); putc_(','); putsig(c1); putc_(','); putsig(c2); putc_(','); putsig(c3); putc_('\n');
    puts_("END\n");
    while (1) { }
}
