"""Measure the dip of the Preakness / Feltville / Orange Mountain units along cross-section A-A' of GMS 04-02
(Monteverde & Volkert 2005), which is printed with no vertical exaggeration as a raster strip down the left
margin of the sheet.  Method: render the strip, trace the left (down-section = NW) edge of the Orange Mountain
Basalt band (its colour is unique on the section) row by row, and fit the local slope in 100-pt windows.
Both axes of the section are ~8.5 m per PDF point (1:24,000; 1000 ft = 35 pt), so dip = atan(dx/dy)."""
import sys, numpy as np, pymupdf
from PIL import Image
pdf = "data/raw/sources/gms04-2/gms04-2.pdf"
pg = pymupdf.open(pdf)[0]
Z = 4
clip = pymupdf.Rect(20, 240, 165, 2060)
pix = pg.get_pixmap(matrix=pymupdf.Matrix(Z, Z), clip=clip)
img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)[:, :, :3].astype(int)
# scale: 1000-ft tick at x=127.5 pt, sea level at x=162.5 pt (read from the rendered axis) -> 35 pt / 304.8 m
M_PER_PT_V = 304.8 / 35.0
M_PER_PT_H = 10550.0 / 1214.0   # 7.5' of longitude across 1214 pt of neatline
print("m/pt vertical %.2f, horizontal %.2f" % (M_PER_PT_V, M_PER_PT_H))
# unique colours in the strip
cols, counts = np.unique(img.reshape(-1, 3), axis=0, return_counts=True)
order = np.argsort(-counts)
for i in order[:14]:
    print("colour", tuple(cols[i]), counts[i])
def edge_profile(target, tol=28):
    """left-most x (px) of pixels within tol of target colour, per row"""
    d = np.abs(img - np.array(target)).sum(axis=2)
    mask = d < tol
    xs = np.full(img.shape[0], np.nan)
    for r in range(img.shape[0]):
        w = np.where(mask[r])[0]
        if w.size > 6:
            xs[r] = w[0]
    return xs
targets = {k: tuple(cols[i]) for k, i in zip(["c%d" % j for j in range(14)], order[:14])}
for name in sys.argv[1:] or []:
    pass
# Orange Mountain Basalt on the section is the gold/brown band; find the colour nearest to (200,160,60)
gold = min((tuple(c) for c in cols[order[:30]]), key=lambda c: abs(c[0] - 200) + abs(c[1] - 160) + abs(c[2] - 60))
print("gold band colour", gold)
xs = edge_profile(gold)
rows = np.arange(img.shape[0])
ok = ~np.isnan(xs)
print("rows with the band: %d of %d" % (ok.sum(), len(rows)))
win = 100 * Z
print("position along A-A' (pt from A, m)  ->  local dip toward NW (deg), fitted over 100 pt windows")
out = []
for r0 in range(0, img.shape[0] - win, win // 2):
    sel = ok.copy(); sel[:r0] = False; sel[r0 + win:] = False
    if sel.sum() < win * 0.6:
        continue
    a, b = np.polyfit(rows[sel], xs[sel], 1)   # x = a*row + b ; a in px/px
    dip = np.degrees(np.arctan(-a * M_PER_PT_V / M_PER_PT_H))  # x grows toward sea level... sign fixed below
    pos_pt = 240 - 250 + (r0 + win / 2) / Z
    out.append((pos_pt, dip))
    print("  %6.0f pt  %6.0f m   dip %5.1f" % (pos_pt, pos_pt * M_PER_PT_H, dip))
np.save("C:/Users/Lee/AppData/Local/Temp/claude/aec1bafd7522b934/a3795831-6dc3-4154-ae0f-8e0feae75547/scratchpad/dip_profile.npy", np.array(out))
