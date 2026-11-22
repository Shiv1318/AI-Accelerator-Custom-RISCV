import re, sys
src, dst, ncyc = sys.argv[1], sys.argv[2], int(sys.argv[3])
text = open(src).read()
m = re.search(r"\$timescale\s+(\d+)\s*(fs|ps|ns)\s*\$end", text)
mult = {"fs": 1e-15, "ps": 1e-12, "ns": 1e-9}
f = int(m.group(1)) * mult[m.group(2)]
period = int(round(20e-9 / f))
hdr, body = text.split("$enddefinitions", 1)
body = "$enddefinitions" + body
lines, t0 = [], None
for l in body.split("\n"):
    if l.startswith("#"):
        t = int(l[1:])
        if t0 is None: t0 = t
        lines.append("#%d" % (t - t0))
    else:
        lines.append(l)
lines.append("#%d" % (ncyc * period))
open(dst, "w").write(hdr + "\n".join(lines) + "\n")
print("timescale", m.group(0).split()[1], m.group(2), "t0", t0, "period units", period)
