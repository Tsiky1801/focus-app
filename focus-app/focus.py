import json
import os
import time
from datetime import datetime

FICHIER_STATS = "stats.json"


def charger_stats():
    if os.path.exists(FICHIER_STATS):
        with open(FICHIER_STATS, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def sauvegarder_stats(stats):
    with open(FICHIER_STATS, "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)


def ajouter_matiere():
    matiere = input("Nom de la matière : ").strip()
    return matiere


def session_concentration():
    matiere = ajouter_matiere()
    try:
        minutes = int(input("Durée de la session (en minutes) : "))
    except ValueError:
        print("⚠️ Nombre invalide, session de 25 minutes par défaut.")
        minutes = 25

    print(f"\n⏱️ C'est parti pour {minutes} minutes de {matiere} ! (Ctrl+C pour arrêter)\n")
    debut = time.time()
    try:
        for reste in range(minutes * 60, 0, -1):
            m, s = divmod(reste, 60)
            print(f"\r⏳ Temps restant : {m:02d}:{s:02d}", end="")
            time.sleep(1)
        print("\n\n🎉 Session terminée, bravo !")
        duree = minutes
    except KeyboardInterrupt:
        duree = int((time.time() - debut) // 60)
        print(f"\n⏹️ Session arrêtée après {duree} min.")

    stats = charger_stats()
    stats.append({
        "matiere": matiere,
        "minutes": duree,
        "date": datetime.now().strftime("%d/%m/%Y %H:%M"),
    })
    sauvegarder_stats(stats)
    print("✅ Session enregistrée !")


def voir_stats():
    stats = charger_stats()
    if not stats:
        print("📭 Aucune session enregistrée.")
        return
    total = sum(s["minutes"] for s in stats)
    print(f"\n📊 {len(stats)} sessions | ⏱️ Total : {total} minutes\n")
    for s in stats:
        print(f"- {s['date']} | {s['matiere']} | {s['minutes']} min")


def menu():
    while True:
        print("\n===== 🎓 FOCUS - App d'étude =====")
        print("1. Lancer une session de concentration")
        print("2. Voir mes statistiques")
        print("3. Quitter")
        choix = input("Ton choix : ").strip()
        if choix == "1":
            session_concentration()
        elif choix == "2":
            voir_stats()
        elif choix == "3":
            print("À bientôt ! 👋")
            break
        else:
            print("⚠️ Choix invalide.")


if __name__ == "__main__":
    menu()
