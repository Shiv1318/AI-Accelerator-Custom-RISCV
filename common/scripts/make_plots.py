import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
OUT = "results/plots_20nov/"
A = [("iter","star",10593.9,60.3),("iter","booth",9665.5,74.8),("iter","wallace",9649.3,63.4),
     ("iter","array",10161.0,74.4),("iter","shift-add",10413.7,469.6),
     ("par","star",19497.4,18.9),("par","booth",15727.6,21.2),("par","wallace",16379.5,18.3),
     ("par","array",18502.7,21.0),
     ("systolic","star",21284.2,30.3),("systolic","booth",17564.3,41.1),
     ("systolic","wallace",17830.9,39.2),("systolic","array",19806.5,39.0),
     ("iter","dadda",9389.0,73.0),("par","dadda",15621.2,20.5),("systolic","dadda",17301.6,37.5)]
mk = {"iter":"o","par":"s","systolic":"^"}
fig, ax = plt.subplots(figsize=(8,5.5))
for arch in mk:
    pts = [p for p in A if p[0]==arch]
    ax.scatter([p[3] for p in pts],[p[2] for p in pts],marker=mk[arch],s=70,label=arch)
    for p in pts:
        ax.annotate(p[1],(p[3],p[2]),textcoords="offset points",xytext=(5,4),fontsize=8)
ax.set_xscale("log")
ax.set_xlabel("Compute latency (ns) = HW cycles x critical delay, no bus")
ax.set_ylabel("Cell area (um2), sky130hd tt, 20 ns")
ax.set_title("Area vs compute latency, 13 configurations (Table 5.5b)")
ax.grid(True,alpha=0.3); ax.legend()
fig.tight_layout(); fig.savefig(OUT+"fig1_area_vs_latency.png",dpi=200)
import numpy as np
names = ["par","systolic","iter","iter shift-add"]
run3 = [38,41,44,116]; packall = [258,261,264,336]; axi = [424,424,424,508]
x = np.arange(4); w = 0.27
fig, ax = plt.subplots(figsize=(8,5))
for off,v,l in [(-w,run3,"XMAT RUN+3 GET (pre-packed)"),(0,packall,"XMAT with packing (220 cycles)"),(w,axi,"AXI-Lite path")]:
    b = ax.bar(x+off,v,w,label=l)
    ax.bar_label(b,fontsize=8)
ax.set_xticks(x); ax.set_xticklabels(names)
ax.set_ylabel("Cycles (rdcycle to rdcycle, 18 sets)")
ax.set_title("Accelerator access cost: XMAT vs AXI-Lite")
ax.legend(); ax.grid(True,axis="y",alpha=0.3)
fig.tight_layout(); fig.savefig(OUT+"fig2_xmat_cycles.png",dpi=200)
arch = ["iter","par","systolic"]
axi_a = [177799,186859,188779]; xm_a = [190834,208783,212984]; pct = ["+7.3%","+11.7%","+12.8%"]
x = np.arange(3); w = 0.35
fig, ax = plt.subplots(figsize=(7,5))
b1 = ax.bar(x-w/2,axi_a,w,label="AXI only"); b2 = ax.bar(x+w/2,xm_a,w,label="AXI + XMAT")
for i in range(3):
    ax.annotate(pct[i],(x[i]+w/2,xm_a[i]),textcoords="offset points",xytext=(0,4),ha="center",fontsize=9)
ax.set_xticks(x); ax.set_xticklabels(arch)
ax.set_ylabel("Cell area (um2), synthesis only, no routing")
ax.set_ylim(150000,225000)
ax.set_title("SoC area with and without XMAT")
ax.legend(); ax.grid(True,axis="y",alpha=0.3)
fig.tight_layout(); fig.savefig(OUT+"fig3_soc_area_overhead.png",dpi=200)
