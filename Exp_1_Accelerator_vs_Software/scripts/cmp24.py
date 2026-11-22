import re, sys
def load(p, arch, mult):
    d, cur = {}, None
    for l in open(p):
        m = re.search(r"arch=(\d) mult=(\d)", l)
        if m and "cpu=" not in l: cur = (int(m[1]), int(m[2])); continue
        m = re.search(r"\b([SR]\d+) cpu=(\d+) e2e=(\d+) hw=(\d+) ok=(\d)(?: gold=\d)?(?: c=(\S+))?", l)
        if m and cur == (arch, mult): d[m[1]] = m.groups()[1:]
    return d
old = load("results/simulation/soc_all_configs_v4.log", int(sys.argv[2]), int(sys.argv[3]))
new = load(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
bad = [k for k in new if k not in old or old[k] != new[k]]
print("compared:", len(new), "| mismatches:", len(bad), bad[:5])
