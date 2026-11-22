// CPU-only vs accelerator 2x2 matmul on PicoRV32. No libc, no globals, no hardware multiply.
#define REG(o)   (*(volatile unsigned *)(0x20000000u + (o)))
#define UART_TX  (*(volatile char *)0x10000000)

static inline unsigned rdcycle(void) {
    unsigned c; __asm__ volatile ("csrr %0, cycle" : "=r"(c)); return c;
}
static void putc_(char c) { UART_TX = c; }
static void puts_(const char *s) { while (*s) putc_(*s++); }
static void putdec(unsigned v) {
    static const unsigned p10[10] = {1000000000u,100000000u,10000000u,1000000u,100000u,10000u,1000u,100u,10u,1u};
    int started = 0;
    for (int i = 0; i < 10; i++) {
        unsigned d = 0;
        while (v >= p10[i]) { v -= p10[i]; d++; }
        if (d || started || i == 9) { putc_((char)('0' + d)); started = 1; }
    }
}

// software signed multiply (shift-add); latency depends on the multiplier value
static int sw_mul(int a, int b) {
    int neg = (a < 0) ^ (b < 0);
    unsigned ua = a < 0 ? (unsigned)(-a) : (unsigned)a;
    unsigned ub = b < 0 ? (unsigned)(-b) : (unsigned)b;
    unsigned r = 0;
    while (ub) { if (ub & 1u) r += ua; ua <<= 1; ub >>= 1; }
    return neg ? -(int)r : (int)r;
}
static inline __attribute__((always_inline)) void cpu_matmul(const int *a, const int *b, int *c) {
    for (int i = 0; i < 2; i++)
        for (int j = 0; j < 2; j++)
            c[i*2 + j] = sw_mul(a[i*2 + 0], b[0*2 + j]) + sw_mul(a[i*2 + 1], b[1*2 + j]);
}

// accelerator path: load A,B -> START -> poll DONE -> read C. Returns the HW CYCLES register.
static inline __attribute__((always_inline)) unsigned acc_matmul(const int *a, const int *b, int *c) {
    for (int i = 0; i < 4; i++) REG(0x10 + 4*i) = (unsigned)a[i];
    for (int i = 0; i < 4; i++) REG(0x20 + 4*i) = (unsigned)b[i];
    REG(0x00) = 1u;
    while (!(REG(0x04) & 2u)) { }
    unsigned hw = REG(0x08);
    for (int i = 0; i < 4; i++) c[i] = (int)REG(0x30 + 4*i);
    return hw;
}

static void putsig(int v) { if (v < 0) { putc_('-'); putdec((unsigned)(-v)); } else putdec((unsigned)v); }
static void run_set(const char *name, const int *a, const int *b, const int *gold, int showc) {
    int cc[4], ca[4];
    unsigned t0 = rdcycle(); cpu_matmul(a, b, cc);          unsigned t1 = rdcycle();
    unsigned t2 = rdcycle(); unsigned hw = acc_matmul(a, b, ca); unsigned t3 = rdcycle();
    int ok = 1, gd = 1;
    for (int i = 0; i < 4; i++) { if (cc[i] != ca[i]) ok = 0; if (gold && ca[i] != gold[i]) gd = 0; }
    puts_(name); puts_(" cpu="); putdec(t1 - t0);
    puts_(" e2e="); putdec(t3 - t2);
    puts_(" hw="); putdec(hw);
    puts_(" ok="); putc_(ok ? '1' : '0');
    if (gold) { puts_(" gold="); putc_(gd ? '1' : '0'); }
    if (showc) { puts_(" c="); for (int i = 0; i < 4; i++) { if (i) putc_(','); putsig(ca[i]); } }
    putc_('\n');
}

static unsigned rnd(unsigned *s) { unsigned x = *s; x ^= x << 13; x ^= x >> 17; x ^= x << 5; *s = x; return x; }
static void run_rand(char t, char o, unsigned *st) {
    int a[4], b[4]; char nm[4];
    for (int i = 0; i < 4; i++) a[i] = (signed char)(rnd(st) >> 24);
    for (int i = 0; i < 4; i++) b[i] = (signed char)(rnd(st) >> 24);
    nm[0] = 'R'; nm[1] = t; nm[2] = o; nm[3] = 0;
    run_set(nm, a, b, 0, 1);
}
int main(void) {
    int a1[4], b1[4], g1[4], a2[4], b2[4];
    a1[0]=1; a1[1]=2; a1[2]=3; a1[3]=4;
    b1[0]=5; b1[1]=6; b1[2]=7; b1[3]=8;
    g1[0]=19; g1[1]=22; g1[2]=43; g1[3]=50;
    a2[0]=-128; a2[1]=127; a2[2]=100; a2[3]=-100;
    b2[0]=-128; b2[1]=-128; b2[2]=127; b2[3]=127;

    unsigned id = REG(0x40);
    puts_("arch="); putdec(id & 0xffu); puts_(" mult="); putdec(id >> 8); putc_('\n');
    run_set("S1", a1, b1, g1, 0);
    run_set("S2", a2, b2, 0, 0);
    { unsigned st = 0x2545F491u;
      for (int k = 0; k < 16; k++) run_rand(k < 9 ? '0' : '1', (char)('0' + (k < 9 ? k + 1 : k - 9)), &st); }
    puts_("END\n");
    while (1) { }
}
