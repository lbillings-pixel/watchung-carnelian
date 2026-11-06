"""Render selected PDF pages / clips to PNG for visual checking.
Usage: render_source_pages.py <pdf> <page> <zoom> <out> [x0 y0 x1 y1 in points]"""
import sys, pymupdf
pdf, page, zoom, out = sys.argv[1], int(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
doc = pymupdf.open(pdf)
pg = doc[page - 1]
clip = None
if len(sys.argv) > 5:
    x0, y0, x1, y1 = map(float, sys.argv[5:9])
    clip = pymupdf.Rect(x0, y0, x1, y1)
pix = pg.get_pixmap(matrix=pymupdf.Matrix(zoom, zoom), clip=clip)
pix.save(out)
print(out, pix.width, pix.height, "page size", pg.rect)
