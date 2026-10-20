"""Images NovaSTEM : démarrage (case No/102 + « va » + exposant STEM) et bannière Google Play."""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageChops
F = "/tmp/claude-0/fonts/"
ROSE, BLEU = (0xFF,0x5A,0x8A),(0x3D,0x7B,0xFF)
CLAIR, SOMBRE = (0xF2,0xF1,0xF6),(0x0F,0x0F,0x14)
NOIR, BLANC, GRIS = (0x17,0x16,0x1F),(0xF2,0xF1,0xF6),(0x5E,0x5C,0x6B)

def logo(T, fond, trait, sombre, cadre=True, S=4):
    T *= S
    fr = ImageFont.truetype(F+"Fraunces-Bold.ttf", int(T))
    fi = ImageFont.truetype(F+"Figtree-Bold.ttf", int(T*0.23))
    fs = ImageFont.truetype(F+"Figtree-Bold.ttf", int(T*0.36))
    b = round(T*0.068) if cadre else 0
    asc = fr.getmetrics()[0]
    larg = fr.getlength("No")
    pl, pt, pb = (T*0.18 if cadre else T*0.05, T*0.27, T*0.11)
    w_case = (pl*2 if cadre else pl+T*0.06) + larg + 2*b; h_case = pt + T + pb + 2*b
    esp = T*0.36*0.08
    w_stem = sum(fs.getlength(c) for c in "STEM") + esp*3
    w_va = fr.getlength("va")
    W = int(w_case + T*0.07 + w_va + T*0.04 + w_stem + T*0.02); H = int(h_case)
    base = Image.new("RGB",(W,H),fond)
    def couche(c,dx,dy):
        im = Image.new("RGB",(W,H),(0,0,0) if sombre else (255,255,255))
        ImageDraw.Draw(im).text((b+pl+dx,b+pt+dy),"No",font=fr,fill=c); return im
    op = ImageChops.screen if sombre else ImageChops.multiply
    img = op(op(base,couche(ROSE,0,0)),couche(BLEU,T*0.068,T*0.045))
    d = ImageDraw.Draw(img)
    if cadre: d.rectangle([b/2,b/2,w_case-b/2,h_case-b/2],outline=trait,width=b)
    d.text((b+pl-T*0.05,b+pt-T*0.21),"102",font=fi,fill=trait)
    bl = b+pt+asc
    x = w_case+T*0.07
    d.text((x,bl),"va",font=fr,fill=trait,anchor="ls")
    # haut de « va » (hauteur d'x) : STEM aligné en haut
    top_va = d.textbbox((x,bl),"va",font=fr,anchor="ls")[1]
    x += w_va + T*0.04
    for c in "STEM":
        d.text((x,top_va+T*0.01),c,font=fs,fill=trait,anchor="ls"); x += fs.getlength(c)+esp
    return img.resize((W//S,H//S),Image.LANCZOS)

out = sys.argv[1]
logo(300,CLAIR,NOIR,False).save(out+"/demarrage.png")
logo(300,SOMBRE,BLANC,True).save(out+"/demarrage_sombre.png")
# bannière 1024x500 : logo sans cadre + slogan
m = logo(150,CLAIR,NOIR,False)
ban = Image.new("RGB",(1024,500),CLAIR)
ban.paste(m,((1024-m.width)//2,75))
d = ImageDraw.Draw(ban)
f = ImageFont.truetype(F+"Figtree-Medium.ttf",30)
d.text((512,355),"Les avancées scientifiques et technologiques du moment",font=f,fill=GRIS,anchor="mm")
ban.save(out+"/banniere-1024x500.png")
print(m.size)
