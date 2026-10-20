"""Prépare le projet Android pour les notifications (lancé par « Compiler l'app »).

- autorisation d'afficher des notifications (Android 13+) ;
- petite icône blanche « No » de la barre d'état (gardée par le nettoyage R8) ;
- « desugaring » Java exigé par flutter_local_notifications ;
- si le secret GOOGLE_SERVICES_JSON existe : fichier google-services.json,
  module Google Services (Firebase) et Crashlytics (rapports de plantage). Écrit « oui » ou « non » dans
  notifications.txt pour la suite de la compilation.
"""
import os
import re
import shutil
from pathlib import Path

app = Path("android/app")
manifeste = app / "src/main/AndroidManifest.xml"
gradle = app / "build.gradle.kts"
reglages = Path("android/settings.gradle.kts")

# 1) Autorisation POST_NOTIFICATIONS
s = manifeste.read_text(encoding="utf-8")
if "POST_NOTIFICATIONS" not in s:
    s = s.replace("<application",
                  '<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application', 1)
manifeste.write_text(s, encoding="utf-8")

# 2) Petite icône des notifications + protection contre le nettoyage des ressources
dessin = app / "src/main/res/drawable"
dessin.mkdir(parents=True, exist_ok=True)
shutil.copy("assets/icone/notification.png", dessin / "ic_notification.png")
brut = app / "src/main/res/raw"
brut.mkdir(parents=True, exist_ok=True)
(brut / "keep.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources xmlns:tools="http://schemas.android.com/tools" '
    'tools:keep="@drawable/ic_notification" />\n', encoding="utf-8")

# 3) Desugaring (dates Java modernes sur les anciens Android)
g = gradle.read_text(encoding="utf-8")
if "isCoreLibraryDesugaringEnabled" not in g:
    g = re.sub(r"compileOptions \{\n", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n", g, count=1)
    g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'

# 4) Firebase, seulement si la configuration est fournie
config = (os.environ.get("GOOGLE_SERVICES_JSON") or "").strip()
actif = bool(config)
if actif:
    (app / "google-services.json").write_text(config, encoding="utf-8")
    r = reglages.read_text(encoding="utf-8")
    if "com.google.gms.google-services" not in r:
        r = r.replace('id("dev.flutter.flutter-plugin-loader") version "1.0.0"',
                      'id("dev.flutter.flutter-plugin-loader") version "1.0.0"\n'
                      '    id("com.google.gms.google-services") version "4.4.2" apply false\n'
                      '    id("com.google.firebase.crashlytics") version "3.0.2" apply false', 1)
        reglages.write_text(r, encoding="utf-8")
    if "com.google.gms.google-services" not in g:
        g = re.sub(r"plugins \{\n", 'plugins {\n    id("com.google.gms.google-services")\n'
                   '    id("com.google.firebase.crashlytics")\n', g, count=1)
gradle.write_text(g, encoding="utf-8")

Path("notifications.txt").write_text("oui" if actif else "non", encoding="utf-8")
print("::notice title=Notifications::"
      + ("Firebase configuré : notifications actives dans l'APK" if actif
         else "Secret GOOGLE_SERVICES_JSON absent : notifications désactivées dans l'APK"))
