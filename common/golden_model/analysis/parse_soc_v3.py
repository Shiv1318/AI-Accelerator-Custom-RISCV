import re, sys, numpy as np, pandas as pd
log = sys.argv[1] if len(sys.argv) > 1 else "results/simulation/soc_all_configs_v4.log"
pat = re.compile(r"\b([A-Z]\d+) cpu=(\d+) e2e=(\d+) hw=(\d+) ok=(\d)(?: gold=(\d))?(?: c=(-?\d+),(-?\d+),(-?\d+),(-?\d+))?")
rows, arch, mult = [], None, None
for line in open(log):
    m = re.search(r"arch=(\d) mult=(\d)", line)
    if m and "cpu=" not in line: arch, mult = int(m[1]), int(m[2]); continue
    m = pat.search(line)
    if m:
        c = [int(x) for x in m.groups()[6:]] if m[7] is not None else None
        rows.append(dict(dataset=m[1], group=m[1][0], arch=arch, mult=mult, cpu_cycles=int(m[2]), e2e_cycles=int(m[3]),
                         hw_cycles=int(m[4]), ok=int(m[5]), gold=(None if m[6] is None else int(m[6])), c=c))
df = pd.DataFrame(rows)

# independent check of the random sets against NumPy (replicates the firmware xorshift32)
s = 0x2545F491
def rnd():
    global s
    s ^= (s << 13) & 0xFFFFFFFF; s ^= s >> 17; s ^= (s << 5) & 0xFFFFFFFF; return s
exp = {}
for k in range(1, 17):
    a = [((rnd() >> 24) & 0xFF) for _ in range(4)]; b = [((rnd() >> 24) & 0xFF) for _ in range(4)]
    a = np.array([v - 256 if v >= 128 else v for v in a]).reshape(2, 2); b = np.array([v - 256 if v >= 128 else v for v in b]).reshape(2, 2)
    exp["R%02d" % k] = list((a @ b).flatten())
df["numpy_match"] = [None if r.c is None else int(r.c == exp[r.dataset]) for r in df.itertuples()]
df["speedup_e2e"] = (df.cpu_cycles / df.e2e_cycles).round(2)
df["speedup_compute"] = (df.cpu_cycles / df.hw_cycles).round(1)
df.drop(columns="c").to_csv("results/comparison/soc_cpu_vs_accel_v3.csv", index=False)

print("rows:", len(df), "| all ok=1:", bool((df.ok == 1).all()), "| gold failures:", int((df.gold == 0).sum()),
      "| numpy mismatches:", int((df.numpy_match == 0).sum()))
base = df[(df.arch == 0) & (df.mult == 0)]
chk = df.groupby("dataset").cpu_cycles.nunique()
print("CPU cycles identical across configs:", bool((chk == 1).all()))
summ = base.groupby("group").agg(n=("dataset", "count"), cpu_mean=("cpu_cycles", "mean"), cpu_min=("cpu_cycles", "min"),
        cpu_max=("cpu_cycles", "max"), e2e_mean=("e2e_cycles", "mean"), spd_mean=("speedup_e2e", "mean"),
        spd_min=("speedup_e2e", "min"), spd_max=("speedup_e2e", "max")).round(2)
allrow = base.agg(n=("dataset", "count"), cpu_mean=("cpu_cycles", "mean"), cpu_min=("cpu_cycles", "min"), cpu_max=("cpu_cycles", "max"))
print(summ.to_string()); print("ALL sets:", allrow.round(1).to_dict())
summ.to_csv("results/comparison/soc_cpu_summary_v3.csv")
print(df[df.dataset.isin(["S1", "S2"])].drop(columns="c").to_string())
