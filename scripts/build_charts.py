"""Redraw the paper's key data charts from its tables for the evidence panels (data/processed/charts/*.png).

  ree_pattern.png      chondrite-normalised REE of the three Green Brook carnelians (Table 3)  ~ Fig. 8a
  d18o_global.png      carnelian d18O (Table 4) against the global ranges quoted in section 4.6  ~ Fig. 9
  table4_temps.png     Table 4 formation temperatures for meteoric / seawater / magmatic fluid end-members
  table1_alteration.png  Table 1 LOI, Na2O, CaO by position in the first flow (hydrothermal alteration signal)
  table2_crystallite.png Table 2 crystallite size and microstrain, GBR vs SGB
"""
import os
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "processed", "charts")
os.makedirs(OUT, exist_ok=True)
plt.rcParams.update({"font.size": 11, "axes.spines.top": False, "axes.spines.right": False, "figure.dpi": 110})
BG = "#1b1d22"
FG = "#e8e8e8"


def style(ax, fig):
    fig.patch.set_facecolor(BG)
    ax.set_facecolor(BG)
    for s in ax.spines.values():
        s.set_color(FG)
    ax.tick_params(colors=FG)
    ax.xaxis.label.set_color(FG)
    ax.yaxis.label.set_color(FG)
    ax.title.set_color(FG)


# ---- Table 3 REE (ppm) ----
REE = ["La", "Ce", "Pr", "Nd", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"]
T3 = {
    "GBR-02-1": [0.76, 3.65, 0.82, 4.69, 3.90, 0.033, 3.82, 1.69, 15.60, 3.74, 14.10, 3.21, 25.0, 3.98],
    "GBR-02-2": [0.35, 2.02, 0.57, 4.46, 4.64, 0.040, 7.92, 2.06, 15.30, 3.19, 9.99, 1.55, 10.50, 1.44],
    "GBR-02-3": [0.09, 0.58, 0.14, 0.71, 0.67, 0.005, 0.68, 0.28, 2.64, 0.59, 2.47, 0.556, 5.09, 0.768],
}
# Chondrite normalisation: the paper uses Masuda et al. (1973) [51]. Those values are not reproduced in the
# paper; the Nakamura (1974) set (built on Masuda's Leedey chondrite data, with Pr/Tb/Ho/Tm interpolated) is
# used here. Differences between the two sets are a few percent and do not change the pattern shape.
CHON = {"La": 0.329, "Ce": 0.865, "Pr": 0.112, "Nd": 0.630, "Sm": 0.203, "Eu": 0.077, "Gd": 0.276, "Tb": 0.047,
        "Dy": 0.343, "Ho": 0.070, "Er": 0.225, "Tm": 0.035, "Yb": 0.220, "Lu": 0.0339}

fig, ax = plt.subplots(figsize=(6.4, 4.2))
style(ax, fig)
x = np.arange(len(REE))
for name, vals in T3.items():
    ax.plot(x, [v / CHON[e] for v, e in zip(vals, REE)], "o-", label=name)
ax.set_yscale("log")
ax.set_xticks(x)
ax.set_xticklabels(REE)
ax.set_ylabel("sample / chondrite")
ax.set_title("REE patterns of Green Brook carnelian (paper Table 3, cf. Fig. 8a)")
ax.legend(facecolor=BG, labelcolor=FG, edgecolor=FG)
ax.text(0.01, 0.02, "Rising to the heavy REE; deep Eu trough (Eu/Eu* = 0.020-0.026).\n"
        "Preakness basalt/gabbroid curves of Fig. 8a come from Tollo et al. (1990), not tabulated in the paper, so they are not redrawn.\n"
        "Normalised to Nakamura (1974) chondrite (paper: Masuda et al. 1973).",
        transform=ax.transAxes, fontsize=7.5, color="#bbbbbb", va="bottom")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "ree_pattern.png"), facecolor=BG)
plt.close(fig)

# ---- Table 4 d18O and temperatures ----
T4 = [("GBR-1", "red", 28.9, 28, 50, 100), ("GBR-2", "red", 31.2, 19, 39, 82), ("GBR-3", "red-orange", 29.9, 24, 45, 92),
      ("GBR-4", "red-orange", 27.8, 32, 56, 108), ("GBR-5", "yellow", 18.3, 82, 121, 223), ("GBR-6", "yellow", 30.5, 21, 42, 88)]
colors = {"red": "#d9534f", "red-orange": "#e8803c", "yellow": "#e6c84a"}

fig, ax = plt.subplots(figsize=(6.4, 4.2))
style(ax, fig)
glob = [("Agate, Jurassic quartz latite, Namibia [53]", 22.1, 28.8), ("Chalcedony, Karoo basalt, S. Africa [54]", 20.1, 21.2),
        ("Agate, Eocene-Miocene volcanics, Iran [55]", 23.8, 26.6), ("Agate, Parana basalt, Brazil [56]", 24.5, 30.3),
        ("Amethyst geodes, Parana basalt, Uruguay [57]", 21.2, 31.1), ("Agates globally, felsic+mafic hosts [47,58]", 16.4, 33.4)]
for i, (lab, lo, hi) in enumerate(glob):
    ax.barh(i, hi - lo, left=lo, color="#5a6b8a", height=0.55)
    ax.text(lo - 0.3, i, lab, ha="right", va="center", fontsize=7.5, color=FG)
yv = len(glob) + 0.6
for s, col, d, *_ in T4:
    ax.plot(d, yv, "D", color=colors[col], markersize=8, markeredgecolor="white")
ax.text(16.1, yv, "NJ carnelian (this paper, Table 4)", ha="right", va="center", fontsize=8, color=FG)
ax.set_xlim(0, 36)
ax.set_ylim(-0.7, yv + 0.8)
ax.set_yticks([])
ax.set_xlabel("d18O (per mil, VSMOW)")
ax.set_title("Carnelian d18O vs. volcanic-hosted chalcedony worldwide (cf. Fig. 9)")
ax.spines["left"].set_visible(False)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "d18o_global.png"), facecolor=BG)
plt.close(fig)

fig, ax = plt.subplots(figsize=(6.4, 4.2))
style(ax, fig)
x = np.arange(len(T4))
w = 0.26
ax.bar(x - w, [r[3] for r in T4], w, label="meteoric water (-5 per mil)", color="#4c9be8")
ax.bar(x, [r[4] for r in T4], w, label="seawater (0 per mil)", color="#6cc1a8")
ax.bar(x + w, [r[5] for r in T4], w, label="magmatic fluid (+8 per mil)", color="#e8603c")
ax.axhspan(20, 80, color="#ffffff", alpha=0.08)
ax.text(len(T4) - 0.5, 50, "paper's preferred\nrange 20-80 C", ha="right", va="center", fontsize=8, color="#dddddd")
ax.set_xticks(x)
ax.set_xticklabels(["%s\n%s\n%.1f" % (r[0], r[1], r[2]) for r in T4], fontsize=8)
ax.set_ylabel("calculated formation temperature (C)")
ax.set_title("Table 4: formation temperature by assumed fluid d18O")
ax.legend(facecolor=BG, labelcolor=FG, edgecolor=FG, fontsize=8)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "table4_temps.png"), facecolor=BG)
plt.close(fig)

# ---- Table 1 alteration signal by position ----
cols = ["Basalt\nflow base", "Basalt\n20-75 m", "Gabbroid\n85-130 m", "Glass-rich\ngabbroid", "Vesicular\ngabbroid 140 m", "Basalt 25 m\nabove gabbroid", "Basalt\ntop of flow 1", "Basalt\nflow 2 base"]
LOI = [0.72, 0.89, 1.77, 2.33, 2.46, 0.85, 2.29, np.nan]
Na2O = [2.98, 3.03, 3.69, 4.51, 2.77, 3.54, 3.97, 2.49]
CaO = [10.90, 9.50, 7.05, 7.88, 5.72, 8.52, 6.79, 10.05]
Sr = [151, 143, 114, 69, 108, 152, 137, 132]
fig, axs = plt.subplots(2, 2, figsize=(7.2, 5.0), sharex=True)
for ax, vals, lab in zip(axs.ravel(), [LOI, Na2O, CaO, Sr], ["LOI wt.% (hydrous minerals)", "Na2O wt.% (albitization)", "CaO wt.% (plagioclase loss)", "Sr ppm"]):
    style(ax, fig)
    ax.bar(range(len(cols)), vals, color=["#9fa6aa", "#9fa6aa", "#7e7e7e", "#4b2e2e", "#d9534f", "#9fa6aa", "#e07a5f", "#b9b9b9"])
    ax.set_title(lab, fontsize=9)
    ax.set_xticks(range(len(cols)))
    ax.set_xticklabels(cols, fontsize=6.5, rotation=0)
fig.suptitle("Table 1: alteration signals rise in the gabbroid and flow top (paper section 5.2)", color=FG, fontsize=10)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "table1_alteration.png"), facecolor=BG)
plt.close(fig)

# ---- Table 2 crystallite size / microstrain ----
T2 = [("GBR-1", 255, 0.165), ("GBR-2", 333, 0.126), ("GBR-3", 228, 0.184), ("SGB-1", 434, 0.098), ("SGB-2", 542, 0.078)]
fig, ax = plt.subplots(figsize=(6.4, 4.0))
style(ax, fig)
for s, cs, st in T2:
    ax.plot(cs, st, "o", color="#d9534f" if s.startswith("GBR") else "#4c9be8", markersize=9)
    ax.annotate(s, (cs, st), textcoords="offset points", xytext=(6, 4), color=FG, fontsize=8)
ax.set_xlabel("crystallite size (Angstrom, Scherrer, 101 peak)")
ax.set_ylabel("lattice microstrain (%)")
ax.set_title("Table 2: Green Brook (red) vs Stirling Brook (blue) carnelian")
fig.tight_layout()
fig.savefig(os.path.join(OUT, "table2_crystallite.png"), facecolor=BG)
plt.close(fig)
print("charts written to", OUT)
