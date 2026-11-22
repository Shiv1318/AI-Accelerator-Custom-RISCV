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
static unsigned rnd(unsigned *s) { unsigned x = *s; x ^= x << 13; x ^= x >> 17; x ^= x << 5; *s = x; return x; }
static void run_x(const char *nm, const volatile int *a, const volatile int *b) {
    int c0, c1, c2, c3;
    unsigned t0 = rdcycle();
    unsigned pa = ((unsigned)a[0] & 255u) | (((unsigned)a[1] & 255u) << 8) | (((unsigned)a[2] & 255u) << 16) | (((unsigned)a[3] & 255u) << 24);
    unsigned pb = ((unsigned)b[0] & 255u) | (((unsigned)b[1] & 255u) << 8) | (((unsigned)b[2] & 255u) << 16) | (((unsigned)b[3] & 255u) << 24);
    __asm__ volatile ("" :: "r"(pa), "r"(pb));
    unsigned t1 = rdcycle();
    __asm__ volatile (".insn r 0x0b, 0, 0, %0, %1, %2" : "=r"(c0) : "r"(pa), "r"(pb));
    unsigned t2 = rdcycle();
    __asm__ volatile (".insn r 0x0b, 1, 1, %0, x0, x0" : "=r"(c1));
    __asm__ volatile (".insn r 0x0b, 1, 2, %0, x0, x0" : "=r"(c2));
    __asm__ volatile (".insn r 0x0b, 1, 3, %0, x0, x0" : "=r"(c3));
    unsigned t3 = rdcycle();
    puts_(nm); puts_(" pack="); putdec(t1 - t0); puts_(" run="); putdec(t2 - t1);
    puts_(" all="); putdec(t3 - t1); puts_(" full="); putdec(t3 - t0); puts_(" c=");
    putsig(c0); putc_(','); putsig(c1); putc_(','); putsig(c2); putc_(','); putsig(c3); putc_('\n');
}
int main(void) {
    int a[4], b[4]; char nm[4];
    a[0]=1; a[1]=2; a[2]=3; a[3]=4; b[0]=5; b[1]=6; b[2]=7; b[3]=8;
    run_x("S1", a, b);
    a[0]=-128; a[1]=127; a[2]=100; a[3]=-100; b[0]=-128; b[1]=-128; b[2]=127; b[3]=127;
    run_x("S2", a, b);
    unsigned st = 0x2545F491u;
    for (int k = 0; k < 16; k++) {
        for (int i = 0; i < 4; i++) a[i] = (signed char)(rnd(&st) >> 24);
        for (int i = 0; i < 4; i++) b[i] = (signed char)(rnd(&st) >> 24);
        nm[0] = 'R'; nm[1] = (k < 9) ? '0' : '1'; nm[2] = (char)('0' + (k < 9 ? k + 1 : k - 9)); nm[3] = 0;
        run_x(nm, a, b);
    }
    puts_("END\n");
    while (1) { }
}
