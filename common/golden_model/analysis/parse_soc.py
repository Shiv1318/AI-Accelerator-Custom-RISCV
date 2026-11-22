import re, pandas as pd
rows, arch, mult = [], None, None
for line in open("results/simulation/soc_all_configs_v2.log"):
    m = re.search(r"arch=(\d) mult=(\d)", line)
    if m: arch, mult = int(m[1]), int(m[2]); continue
    m = re.search(r"(S\d) cpu=(\d+) e2e=(\d+) hw=(\d+) ok=(\d)", line)
    if m:
        cpu, e2e, hw = int(m[2]), int(m[3]), int(m[4])
        rows.append(dict(dataset=m[1], arch=arch, mult=mult, cpu_cycles=cpu,
                         e2e_cycles=e2e, hw_cycles=hw, ok=int(m[5]),
                         speedup_e2e=round(cpu/e2e,2), speedup_compute=round(cpu/hw,1)))
df = pd.DataFrame(rows)
df.to_csv("results/comparison/soc_cpu_vs_accel_v2.csv", index=False)
print(df.to_string())
