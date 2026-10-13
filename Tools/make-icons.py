"""Rebuild the DentalLab vector mark as PNG/ICO/ICNS (requires Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

root = Path(__file__).resolve().parents[1]
size = 2048
def gradient(stops):
    result = Image.new('RGBA', (size, size))
    pixels = result.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            a, b = stops
            pixels[x, y] = tuple(round(a[i] * (1-t) + b[i] * t) for i in range(3)) + (255,)
    return result

canvas = Image.new('RGBA', (size,size))
shell = Image.new('L', (size,size)); d = ImageDraw.Draw(shell)
d.rounded_rectangle((80,80,1968,1968), radius=430, fill=255)
canvas.paste(gradient(((19,29,51),(12,49,70))), (0,0), shell)
d = ImageDraw.Draw(canvas)
d.rounded_rectangle((83,83,1965,1965), radius=430, outline=(55,138,164,255), width=8)
# The same cubic silhouette as the in-app ToothMark, centered on the tile.
curves = [((38,14),(30,12),(23,18)),((12,27),(16,39),(22,49)),((26,57),(23,81),(34,83)),((44,87),(41,57),(50,57)),((59,57),(56,87),(66,83)),((77,81),(74,57),(78,49)),((84,39),(88,27),(77,18)),((70,12),(62,14),(50,22))]
points = []; start = (50,22)
for a,b,end in curves:
    for i in range(51):
        t=i/50; u=1-t
        points.append(tuple((u*u*u*start[k]+3*u*u*t*a[k]+3*u*t*t*b[k]+t*t*t*end[k])*size/100 for k in (0,1)))
    start=end
mask = Image.new('L',(size,size)); ImageDraw.Draw(mask).polygon(points,fill=255)
glow = Image.new('RGBA',(size,size),(37,188,227,0)); glow.putalpha(mask.filter(ImageFilter.GaussianBlur(40)).point(lambda x: round(x*.22)))
canvas = Image.alpha_composite(canvas,glow)
canvas.paste(gradient(((192,250,255),(12,158,193))), (0,0),mask)
image = canvas.resize((1024,1024),Image.Resampling.LANCZOS)
image.save(root/'Resources'/'DentalLab.png')
image.save(root/'Resources'/'DentalLab.ico',sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
image.save(root/'Resources'/'DentalLab.icns')
print('PNG, ICO and ICNS generated from the DentalLab mark.')
