"""Extract text (and page renders for map sheets) from the PDFs in data/raw/sources/<name>/<name>.pdf."""
import sys, pathlib
import fitz  # PyMuPDF

root = pathlib.Path(__file__).resolve().parents[1] / "data" / "raw" / "sources"
for d in sorted(root.iterdir()):
    pdf = d / f"{d.name}.pdf"
    if not pdf.exists():
        continue
    doc = fitz.open(pdf)
    out = d / f"{d.name}_text.txt"
    with out.open("w", encoding="utf-8") as f:
        for i, page in enumerate(doc):
            f.write(f"\n\n===== PAGE {i+1} ({page.rect.width:.0f}x{page.rect.height:.0f} pt) =====\n")
            f.write(page.get_text("text"))
    print(d.name, len(doc), "pages ->", out.name, out.stat().st_size, "bytes")
