import pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
df = pd.read_csv("results/comparison/multiplier_comparison.csv")
fig, ax = plt.subplots(1, 3, figsize=(12, 3.5))
for a, col, t in zip(ax, ["area_um2", "crit_delay_ns", "latency_ns"],
                     ["Area (um2)", "Delay per cycle/multiply (ns)", "Total latency (ns)"]):
    a.bar(df["mult"], df[col]); a.set_title(t)
plt.tight_layout(); plt.savefig("results/comparison/multiplier_comparison.png", dpi=150)
print(df.to_string())
