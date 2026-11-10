"""Captures de la fiche Google Play (1080 x 1920), même style que store/captures-v2/ :
titre sur deux lignes (noir puis bleu), téléphone au cadre noir, capture d'écran à l'intérieur.

Usage : python captures_fiche.py <dossier des captures brutes> <dossier de sortie> <langue fr|en>
Les captures brutes (1080 x 2400, telles que prises sur le téléphone) s'appellent 1.jpg à 8.jpg :
  1 accueil Sciences · 2 avancée ouverte (haut) · 3 même avancée (bas) · 4 accueil Technologies
  5 À venir · 6 page d'un domaine triée « Plus important » · 7 Vocabulaire (définition) · 8 accueil en thème sombre
Polices : Bricolage Grotesque (titres), à côté de ce fichier dans polices/.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1080, 1920
FOND, NOIR, BLEU = (242, 241, 246), (23, 22, 31), (61, 123, 255)
ICI = os.path.dirname(os.path.abspath(__file__))
HAUT_STATUT = 110      # barre d'état du téléphone (heure, batterie) retirée
BAS_UTILE = 2290       # au-delà : barre de navigation Android, retirée

TITRES = {
    "fr": [("Les avancées du jour,", "sans rien rater"),
           ("Comprendre", "en une minute"),
           ("La tech aussi,", "racontée simplement"),
           ("Les grands rendez-vous", "à ne pas manquer"),
           ("Chaque avancée notée", "de 1 à 5 étoiles"),
           ("Les mots difficiles,", "expliqués simplement"),
           ("Aussi", "en thème sombre")],
    "en": [("Today's breakthroughs,", "never miss one"),
           ("Understand it", "in one minute"),
           ("Tech news too,", "told simply"),
           ("Big events", "you won't want to miss"),
           ("Every breakthrough", "rated from 1 to 5 stars"),
           ("Tricky words,", "explained simply"),
           ("Also", "in dark mode")],
}
# Position (haut, bas) du bloc « Voir la vidéo » et de la carte de la source dans la capture 3 brute.
ZONES_DETAIL = [(1320, 1545), (1590, 1800)]
NOMS = ["01_avancees", "02_detail", "03_technologies", "04_a_venir", "05_notes", "06_vocabulaire", "07_sombre"]


def police(taille):
    f = ImageFont.truetype(os.path.join(ICI, "polices", "bric.ttf"), taille)
    f.set_variation_by_axes([96, 800, 100])
    return f


def ligne(d, txt, base, coul, taille=88, serrage=-0.045):
    f = police(taille)
    largeurs = [f.getlength(c) + taille * serrage for c in txt]
    total = sum(largeurs) - taille * serrage
    if total > W - 100:                       # titre trop long : on réduit
        return ligne(d, txt, base, coul, int(taille * (W - 100) / total), serrage)
    x = (W - total) / 2
    for c, l in zip(txt, largeurs):
        d.text((x, base), c, font=f, fill=coul, anchor="ls")
        x += l


def fond_titre(t1, t2):
    im = Image.new("RGB", (W, H), FOND)
    d = ImageDraw.Draw(im)
    ligne(d, t1, 192, NOIR)
    ligne(d, t2, 280, BLEU)
    return im


def ecran(capture, haut=HAUT_STATUT, bas=BAS_UTILE):
    if isinstance(capture, Image.Image):
        return capture
    return Image.open(capture).convert("RGB").crop((0, haut, 1080, bas))


def telephone(img, largeur_ecran, hauteur_ecran, bord=22, rayon=96):
    """Téléphone au cadre noir arrondi (RGBA) contenant img mis à la largeur de l'écran."""
    r = largeur_ecran / img.width
    img = img.resize((largeur_ecran, int(img.height * r)), Image.LANCZOS).crop((0, 0, largeur_ecran, hauteur_ecran))
    w, h = largeur_ecran + 2 * bord, hauteur_ecran + 2 * bord
    tel = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(tel).rounded_rectangle((0, 0, w - 1, h - 1), radius=rayon, fill=NOIR + (255,))
    masque = Image.new("L", img.size, 0)
    ImageDraw.Draw(masque).rounded_rectangle((0, 0, img.width - 1, img.height - 1), radius=rayon - bord, fill=255)
    tel.paste(img, (bord, bord), masque)
    return tel


def page_simple(capture, t1, t2):
    im = fond_titre(t1, t2)
    tel = telephone(ecran(capture), 780, 1458 + 120)       # dépasse en bas, comme les anciennes
    im.paste(tel, (150, 440), tel)
    return im


ENCADRES = {"fr": ("La vidéo du sujet", "Les sources"), "en": ("A video on the topic", "The sources")}


def encadrer(img, zones, langue):
    """Met en avant des zones de la capture (y début, y fin, dans la capture brute) : cadre bleu + étiquette."""
    img = img.copy()
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(os.path.join(ICI, "polices", "figtree.ttf"), 40)
    try:
        f.set_variation_by_name("ExtraBold")
    except Exception:
        pass
    for (y0, y1), txt in zip(zones, ENCADRES[langue]):
        y0, y1 = y0 - HAUT_STATUT, y1 - HAUT_STATUT
        d.rounded_rectangle((40, y0, 1040, y1), radius=44, outline=BLEU, width=9)
        l = d.textlength(txt, font=f)
        d.rounded_rectangle((70, y0 - 30, 70 + l + 44, y0 + 30), radius=30, fill=BLEU)
        d.text((92, y0), txt, font=f, fill=(255, 255, 255), anchor="lm")
    return img


def page_detail(haut, bas, t1, t2, zones=None, langue="fr"):
    im = fond_titre(t1, t2).convert("RGBA")
    for capture, angle, pos in ((haut, 3, (0, 400)), (bas, -3, (500, 570))):
        img = ecran(capture)
        if capture == bas and zones:
            img = encadrer(img, zones, langue)
        tel = telephone(img, 530, int(530 * (BAS_UTILE - HAUT_STATUT) / 1080), bord=16, rayon=66)
        tel = tel.rotate(angle, resample=Image.BICUBIC, expand=True)
        m = 60  # marge pour que le flou de l'ombre ne soit pas coupé
        ombre = Image.new("RGBA", (tel.width + 2 * m, tel.height + 2 * m), (0, 0, 0, 0))
        a = Image.new("L", ombre.size, 0)
        a.paste(tel.getchannel("A").point(lambda v: v * 0.18), (m, m))
        ombre.putalpha(a.filter(ImageFilter.GaussianBlur(18)))
        x, y = pos[0] + 6 - m, pos[1] + 18 - m
        cadre = (max(0, -x), max(0, -y))
        im.alpha_composite(ombre.crop((cadre[0], cadre[1], ombre.width, ombre.height)), (max(0, x), max(0, y)))
        im.alpha_composite(tel, pos)
    return im.convert("RGB")


def main(src, sortie, langue):
    os.makedirs(sortie, exist_ok=True)
    t = TITRES[langue]
    c = lambda n: os.path.join(src, f"{n}.jpg")
    pages = [page_simple(c(1), *t[0]), page_detail(c(2), c(3), *t[1], zones=ZONES_DETAIL, langue=langue), page_simple(c(4), *t[2]),
             page_simple(c(5), *t[3]), page_simple(c(6), *t[4]), page_simple(c(7), *t[5]), page_simple(c(8), *t[6])]
    for nom, p in zip(NOMS, pages):
        p.save(os.path.join(sortie, f"{langue}_{nom}.png"))
    print(f"{len(pages)} images dans {sortie}")


if __name__ == "__main__":
    main(*sys.argv[1:4])
