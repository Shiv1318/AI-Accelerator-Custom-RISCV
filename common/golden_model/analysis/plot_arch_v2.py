import pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
v2 = pd.read_csv("results/comparison/architecture_ppa_20ns_v2.csv")
v1 = pd.read_csv("results/comparison/ppa_20ns_systolic_v1_unregistered.csv")
v1 = v1[v1.arch == "systolic"].copy(); v1["arch"] = "systolic_v1"
v2 = v2.copy(); v2.loc[v2.arch == "systolic", "arch"] = "systolic_v2"
cyc = {"iter": 8, "par": 2, "systolic_v1": 4, "systolic_v2": 5}
df = pd.concat([v2[v2.arch != "systolic_v2"], v1, v2[v2.arch == "systolic_v2"]])
df["cycles"] = df.arch.map(cyc)
df["latency_ns_derived"] = (df.cycles * df.crit_delay_ns).round(1)       # DERIVED: cycles x critical delay
df["area_x_cycles"] = (df.area_um2 * df.cycles).round(0)
order = ["iter", "par", "systolic_v1", "systolic_v2"]
df["arch"] = pd.Categorical(df.arch, order, ordered=True); df = df.sort_values(["arch", "mult"])
cols = ["arch", "mult", "cycles", "area_um2", "crit_delay_ns", "latency_ns_derived", "area_x_cycles"]
df[cols].to_csv("results/comparison/architecture_summary_v2.csv", index=False)
print(df[cols].to_string(index=False))

fig, ax = plt.subplots(1, 3, figsize=(14, 3.8))
for a, col, t in zip(ax, ["area_um2", "crit_delay_ns", "latency_ns_derived"],
                     ["Area (um2)", "Critical delay (ns)", "Latency = cycles x delay (ns, derived)"]):
    w = 0.38
    for k, (m, lab) in enumerate([("star", "star"), ("booth", "Booth")]):
        g = df[df.mult == m]
        a.bar([order.index(x) + (k - 0.5) * w for x in g.arch.astype(str)], g[col], w, label=lab)
    a.set_xticks(range(4)); a.set_xticklabels(["iterative", "parallel", "systolic v1", "systolic v2"], fontsize=8); a.set_title(t, fontsize=9)
ax[0].legend()
plt.tight_layout(); plt.savefig("results/comparison/architecture_v2.png", dpi=150)
