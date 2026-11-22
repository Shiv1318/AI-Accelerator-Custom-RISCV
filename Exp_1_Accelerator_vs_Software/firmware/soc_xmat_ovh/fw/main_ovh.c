#define UART_TX (*(volatile char *)0x10000000)
#define RD(t) __asm__ volatile ("csrr %0, cycle" : "=r"(t))
static void putc_(char c) { UART_TX = c; }
static void puts_(const char *s) { while (*s) putc_(*s++); }
static void putdec(unsigned v) {
    static const unsigned p10[10] = {1000000000u,100000000u,10000000u,1000000u,100000u,10000u,1000u,100u,10u,1u};
    int started = 0;
    for (int i = 0; i < 10; i++) { unsigned d = 0; while (v >= p10[i]) { v -= p10[i]; d++; }
        if (d || started || i == 9) { putc_((char)('0' + d)); started = 1; } }
}
static void pr(const char *n, unsigned v) { puts_(n); putc_('='); putdec(v); putc_(' '); }
int main(void) {
    unsigned pa = 0x04030201u, pb = 0x08070605u, x = 7, y = 9, t1, t2, r;
    unsigned e, ad, g1, ru, g4, a4;
    for (int k = 0; k < 3; k++) {
        __asm__ volatile ("" :: "r"(pa), "r"(pb), "r"(x), "r"(y));
        RD(t1); RD(t2); e = t2 - t1;
        RD(t1); __asm__ volatile ("add %0, %1, %2" : "=r"(r) : "r"(x), "r"(y)); RD(t2); ad = t2 - t1;
        RD(t1); __asm__ volatile (".insn r 0x0b, 1, 0, %0, x0, x0" : "=r"(r)); RD(t2); g1 = t2 - t1;
        RD(t1); __asm__ volatile (".insn r 0x0b, 0, 0, %0, %1, %2" : "=r"(r) : "r"(pa), "r"(pb)); RD(t2); ru = t2 - t1;
        RD(t1); __asm__ volatile (".insn r 0x0b, 1, 0, %0, x0, x0\n\t.insn r 0x0b, 1, 1, %0, x0, x0\n\t.insn r 0x0b, 1, 2, %0, x0, x0\n\t.insn r 0x0b, 1, 3, %0, x0, x0" : "=&r"(r)); RD(t2); g4 = t2 - t1;
        RD(t1); __asm__ volatile ("add %0, %1, %2\n\tadd %0, %1, %2\n\tadd %0, %1, %2\n\tadd %0, %1, %2" : "=&r"(r) : "r"(x), "r"(y)); RD(t2); a4 = t2 - t1;
        puts_("k="); putdec((unsigned)k); putc_(' ');
        pr("e", e); pr("add", ad); pr("get", g1); pr("run", ru); pr("get4", g4); pr("add4", a4); putc_('\n');
    }
    puts_("END\n");
    while (1) { }
}
