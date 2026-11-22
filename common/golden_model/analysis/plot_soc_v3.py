import pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
df = pd.read_csv("results/comparison/soc_cpu_vs_accel_v3.csv")
base = df[(df.arch == 0) & (df.mult == 0)].reset_index(drop=True)

fig, ax = plt.subplots(1, 2, figsize=(13, 4))
ax[0].bar(base.dataset, base.cpu_cycles, label="CPU-only (software multiply)")
ax[0].axhline(424, color="red", ls="--", label="Accelerator end-to-end (424, all configs)")
ax[0].set_title("CPU cycles per data set"); ax[0].set_ylabel("cycles"); ax[0].tick_params(axis="x", rotation=90); ax[0].legend(fontsize=8)
ax[1].bar(base.dataset, base.speedup_e2e)
ax[1].axhline(1, color="grey", ls=":")
ax[1].set_title("End-to-end speedup (CPU / accelerator)"); ax[1].set_ylabel("speedup (x)"); ax[1].tick_params(axis="x", rotation=90)
plt.tight_layout(); plt.savefig("results/comparison/soc_speedup_e2e.png", dpi=150)

c = df.groupby("arch").agg(hw=("hw_cycles", "first"), cpu_mean=("cpu_cycles", "mean")).reset_index()
c["compute_speedup_mean"] = (c.cpu_mean / c.hw).round(1)
names = {0: "iterative", 1: "parallel", 2: "systolic v2"}
fig, ax = plt.subplots(figsize=(6, 4))
bars = ax.bar([names[a] for a in c.arch], c.compute_speedup_mean)
for b, v in zip(bars, c.compute_speedup_mean): ax.text(b.get_x() + b.get_width()/2, v, f"{v:,.0f}x", ha="center", va="bottom")
ax.set_ylabel("compute-only speedup (x)"); ax.set_ylim(0, c.compute_speedup_mean.max() * 1.12)
ax.set_title("Compute-only speedup\n(mean CPU cycles / accelerator CYCLES register, excludes bus time)", fontsize=9)
plt.tight_layout(); plt.savefig("results/comparison/soc_speedup_compute.png", dpi=150)
print(c.to_string())
