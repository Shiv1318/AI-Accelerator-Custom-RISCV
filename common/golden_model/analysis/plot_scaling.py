import pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
df = pd.concat([pd.read_csv(f"results/comparison/ppa_20ns_N{n}.csv").assign(N=n) for n in (2, 4, 8)])
df[["arch", "mult", "N", "cells", "area_um2"]].to_csv("results/comparison/scaling_all.csv", index=False)
fig, ax = plt.subplots(figsize=(6, 4))
for (a, m), g in df.groupby(["arch", "mult"]):
    ax.plot(g.N, g.area_um2, marker="o", label=f"{a}-{m}")
ax.set_xscale("log", base=2); ax.set_yscale("log")
ax.set_xticks([2, 4, 8]); ax.set_xticklabels([2, 4, 8])
ax.set_xlabel("N"); ax.set_ylabel("Area (um2)")
ax.set_title("Area vs N (synthesis only, systolic v1,\nN=4/8 not simulated)", fontsize=9)
ax.legend(fontsize=7)
plt.tight_layout(); plt.savefig("results/comparison/scaling.png", dpi=150)
print(df[["arch", "mult", "N", "cells", "area_um2"]].to_string())
