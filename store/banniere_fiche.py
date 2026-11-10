"""Image de présentation Google Play (1024 x 500), même style que captures-v2/fr_banniere :
logo à gauche, phrase sur 3 lignes (la dernière en bleu), téléphone incliné à droite avec la capture de l'accueil.

Usage : python banniere_fiche.py <capture brute de l'accueil 1080x2400> <fichier de sortie> <fr|en>
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

ICI = os.path.dirname(os.path.abspath(__file__))
P = lambda n: os.path.join(ICI, "polices", n)
FOND, NOIR, BLEU, ROSE = (242, 241, 246), (23, 22, 31), (61, 123, 255), (255, 90, 138)
TEXTES = {"fr": ("Les vraies avancées", "scientifiques et tech,", "expliquées et notées."),
          "en": ("Real science and tech", "breakthroughs,", "explained and rated.")}


def police(fichier, taille, style="Bold"):
    f = ImageFont.truetype(P(fichier), taille)
    try:
        f.set_variation_by_name(style)
    except Exception:
        pass
    return f


def logo(T, S=4):
    """Logo NovaSTEM sur fond clair (même dessin que l'app et design/novastem.py)."""
    T *= S
    fr, fi, fs = police("fraunces.ttf", int(T)), police("figtree.ttf", int(T * 0.23)), police("figtree.ttf", int(T * 0.36))
    b = round(T * 0.068)
    asc = fr.getmetrics()[0]
    pl, pt, pb = T * 0.18, T * 0.27, T * 0.11
    w_case, h_case = pl * 2 + fr.getlength("No") + 2 * b, pt + T + pb + 2 * b
    esp = T * 0.36 * 0.08
    w_stem = sum(fs.getlength(c) for c in "STEM") + esp * 3
    W, H = int(w_case + T * 0.07 + fr.getlength("va") + T * 0.04 + w_stem + T * 0.02), int(h_case)
    base = Image.new("RGB", (W, H), FOND)

    def couche(c, dx, dy):
        im = Image.new("RGB", (W, H), (255, 255, 255))
        ImageDraw.Draw(im).text((b + pl + dx, b + pt + dy), "No", font=fr, fill=c)
        return im
    img = ImageChops.multiply(ImageChops.multiply(base, couche(ROSE, 0, 0)), couche(BLEU, T * 0.068, T * 0.045))
    d = ImageDraw.Draw(img)
    d.rectangle([b / 2, b / 2, w_case - b / 2, h_case - b / 2], outline=NOIR, width=b)
    d.text((b + pl - T * 0.05, b + pt - T * 0.21), "102", font=fi, fill=NOIR)
    bl, x = b + pt + asc, w_case + T * 0.07
    d.text((x, bl), "va", font=fr, fill=NOIR, anchor="ls")
    haut_va = d.textbbox((x, bl), "va", font=fr, anchor="ls")[1]
    x += fr.getlength("va") + T * 0.04
    for c in "STEM":
        d.text((x, haut_va + T * 0.01), c, font=fs, fill=NOIR, anchor="ls")
        x += fs.getlength(c) + esp
    return img.resize((W // S, H // S), Image.LANCZOS)


def main(capture, sortie, langue):
    ban = Image.new("RGBA", (1024, 500), FOND + (255,))
    # téléphone incliné à droite
    ecran = Image.open(capture).convert("RGB").crop((0, 110, 1080, 2290))
    lw, bord, r = 300, 9, 38
    ecran = ecran.resize((lw, int(ecran.height * lw / 1080)), Image.LANCZOS)
    tel = Image.new("RGBA", (lw + 2 * bord, ecran.height + 2 * bord), (0, 0, 0, 0))
    ImageDraw.Draw(tel).rounded_rectangle((0, 0, tel.width - 1, tel.height - 1), radius=r, fill=NOIR + (255,))
    m = Image.new("L", ecran.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, ecran.width - 1, ecran.height - 1), radius=r - bord, fill=255)
    tel.paste(ecran, (bord, bord), m)
    tel = tel.rotate(-7, resample=Image.BICUBIC, expand=True)
    ombre = Image.new("RGBA", (tel.width + 80, tel.height + 80), (0, 0, 0, 0))
    a = Image.new("L", ombre.size, 0)
    a.paste(tel.getchannel("A").point(lambda v: v * 0.16), (40, 40))
    ombre.putalpha(a.filter(ImageFilter.GaussianBlur(14)))
    ban.alpha_composite(ombre, (640 - 40 + 4, 20 - 40 + 12))
    ban.alpha_composite(tel, (640, 20))
    ban = ban.convert("RGB")
    # logo et phrase
    lg = logo(62)
    ban.paste(lg, (60, 76))
    d = ImageDraw.Draw(ban)
    t1, t2, t3 = TEXTES[langue]
    f = police("bric.ttf", 46, "ExtraBold")
    f.set_variation_by_axes([96, 750, 100])
    for i, (t, c) in enumerate(((t1, NOIR), (t2, NOIR), (t3, BLEU))):
        d.text((58, 248 + i * 54), t, font=f, fill=c, anchor="ls")
    ban.save(sortie)
    print(sortie)


if __name__ == "__main__":
    main(*sys.argv[1:4])
