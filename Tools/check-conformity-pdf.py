"""Render and inspect only the synthetic PDF produced by --preview in CI."""
from pathlib import Path
import base64
import pymupdf

path = Path('previews/DentalLab-Conformita-bozza.pdf')
doc = pymupdf.open(path)
assert len(doc) > 1, 'Long prescriptions must span pages'
text = '\n'.join(page.get_text() for page in doc)
assert 'BOZZA' in text and '2M2' in text and 'Faccetta' in text
assert 'àèìòù' in text and 'ULTIMA RIGA DI PROVA' in text
for i, page in enumerate(doc):
    for x0,y0,x1,y1,*_ in page.get_text('blocks'):
        assert x0 >= 0 and y0 >= 0 and x1 <= page.rect.width+1 and y1 <= page.rect.height+1, 'Text outside page'
    page.get_pixmap(matrix=pymupdf.Matrix(1.2,1.2)).save(path.with_name(f'conformita-pagina-{i+1}.png'))
print(f'PASS: {len(doc)} PDF pages, Unicode, tooth assignments and final line preserved.')
# Review the rendered first/last pages without exposing any real archive.
for i in (0,len(doc)-1):
    data=doc[i].get_pixmap(matrix=pymupdf.Matrix(1,1)).tobytes('png')
    print('DENTALLAB_SYNTHETIC_PDF_PREVIEW:'+base64.b64encode(data).decode())
