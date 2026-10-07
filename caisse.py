import json
import os
import tkinter as tk
from tkinter import ttk, messagebox, simpledialog

DB_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "produits.json")

PRODUITS_DEFAUT = {
    "Eau minerale 0.5L": 500,
    "Pain": 1200,
    "Lait 1L": 3000,
    "Coca Cola 1.5L": 4500,
    "Croissant": 800,
    "Cafe": 2500,
    "Chocolat": 3500,
    "Yaourt": 700,
}

# ---------- Gestion de la base de donnees ----------
def charger_produits():
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return dict(PRODUITS_DEFAUT)
    sauvegarder_produits(PRODUITS_DEFAUT)
    return dict(PRODUITS_DEFAUT)

def sauvegarder_produits(produits):
    with open(DB_FILE, "w", encoding="utf-8") as f:
        json.dump(produits, f, ensure_ascii=False, indent=2)

produits = charger_produits()
panier = []  # liste de (nom, prix_unitaire, quantite)

# ---------- Couleurs ----------
BG = "#1e2a38"
BG2 = "#2c3e50"
BTN_VERT = "#27ae60"
BTN_ROUGE = "#e74c3c"
BTN_BLEU = "#2980b9"
BTN_ORANGE = "#f39c12"
TEXTE = "#ecf0f1"

# ---------- Application ----------
root = tk.Tk()
root.title("CAISSE MAGASIN")
root.geometry("760x620")
root.configure(bg=BG)

tk.Label(root, text="🛒 CAISSE MAGASIN", font=("Segoe UI", 20, "bold"), bg=BG, fg="#f1c40f").pack(pady=10)

# --- Selection produit ---
frame_haut = tk.Frame(root, bg=BG)
frame_haut.pack(pady=5)

tk.Label(frame_haut, text="Produit :", font=("Segoe UI", 12), bg=BG, fg=TEXTE).grid(row=0, column=0, padx=5)
combo = ttk.Combobox(frame_haut, values=sorted(produits.keys()), width=25, font=("Segoe UI", 11))
combo.grid(row=0, column=1, padx=5, pady=5)

tk.Label(frame_haut, text="Quantite :", font=("Segoe UI", 12), bg=BG, fg=TEXTE).grid(row=0, column=2, padx=5)
spin_qte = tk.Spinbox(frame_haut, from_=1, to=999, width=5, font=("Segoe UI", 11))
spin_qte.delete(0, tk.END)
spin_qte.insert(0, "1")
spin_qte.grid(row=0, column=3, padx=5)

lbl_prix = tk.Label(frame_haut, text="Prix : --", font=("Segoe UI", 13, "bold"), fg="#2ecc71", bg=BG)
lbl_prix.grid(row=0, column=4, padx=10)

def afficher_prix(event=None):
    nom = combo.get()
    if nom in produits:
        lbl_prix.config(text=f"Prix : {produits[nom]:,.0f} Ar".replace(",", " "))
    else:
        lbl_prix.config(text="Prix : --")

combo.bind("<<ComboboxSelected>>", afficher_prix)
combo.bind("<KeyRelease>", afficher_prix)

# --- Panier ---
frame_panier = tk.Frame(root, bg=BG2, bd=2, relief="groove")
frame_panier.pack(pady=10, padx=20, fill="x")

tk.Label(frame_panier, text="🧾 Panier :", font=("Segoe UI", 12, "bold"), bg=BG2, fg=TEXTE).pack(anchor="w", padx=10)
listbox = tk.Listbox(frame_panier, width=60, height=7, font=("Consolas", 11), bg="#34495e", fg="white", selectbackground="#f1c40f", selectforeground="black")
listbox.pack(padx=10, pady=5)

lbl_total = tk.Label(frame_panier, text="TOTAL : 0 Ar", font=("Segoe UI", 16, "bold"), fg="#f1c40f", bg=BG2)
lbl_total.pack(pady=5)

def total_panier():
    return sum(p * q for _, p, q in panier)

def fmt(montant):
    return f"{montant:,.0f} Ar".replace(",", " ")

def rafraichir():
    listbox.delete(0, tk.END)
    for nom, prix, qte in panier:
        listbox.insert(tk.END, f"{nom:<28} {qte:>3} x {fmt(prix):>10} = {fmt(prix*qte):>10}")
    lbl_total.config(text=f"TOTAL : {fmt(total_panier())}")

def ajouter_au_panier():
    nom = combo.get()
    if nom in produits:
        try:
            qte = int(spin_qte.get())
            if qte < 1:
                raise ValueError
        except ValueError:
            messagebox.showerror("Erreur", "Quantite invalide.")
            return
        # si le produit est deja la, on additionne les quantites
        for i, (n, p, q) in enumerate(panier):
            if n == nom:
                panier[i] = (n, p, q + qte)
                rafraichir()
                combo.set("")
                lbl_prix.config(text="Prix : --")
                return
        panier.append((nom, produits[nom], qte))
        rafraichir()
        combo.set("")
        lbl_prix.config(text="Prix : --")
        spin_qte.delete(0, tk.END)
        spin_qte.insert(0, "1")
    else:
        messagebox.showinfo("Info", "Selectionnez un produit de la liste.")

def supprimer_article():
    sel = listbox.curselection()
    if not sel:
        messagebox.showinfo("Info", "Cliquez sur un article du panier pour le selectionner.")
        return
    index = sel[0]
    nom = panier[index][0]
    del panier[index]
    rafraichir()
    messagebox.showinfo("OK", f"'{nom}' supprime du panier.")

def vider_panier():
    panier.clear()
    rafraichir()
    lbl_rendu.config(text="Monnaie a rendre : --", fg="#ecf0f1")
    entry_monnaie.delete(0, tk.END)

frame_btn = tk.Frame(frame_panier, bg=BG2)
frame_btn.pack(pady=5)
tk.Button(frame_btn, text="➕ Ajouter au panier", command=ajouter_au_panier, bg=BTN_VERT, fg="white", font=("Segoe UI", 11, "bold"), width=20, bd=0, pady=6, cursor="hand2").pack(side="left", padx=10)
tk.Button(frame_btn, text="➖ Supprimer article", command=supprimer_article, bg="#d35400", fg="white", font=("Segoe UI", 11, "bold"), width=20, bd=0, pady=6, cursor="hand2").pack(side="left", padx=10)
tk.Button(frame_btn, text="🗑 Vider le panier", command=vider_panier, bg=BTN_ROUGE, fg="white", font=("Segoe UI", 11, "bold"), width=20, bd=0, pady=6, cursor="hand2").pack(side="left", padx=10)

# --- Paiement ---
frame_paiement = tk.Frame(root, bg=BG)
frame_paiement.pack(pady=10)

tk.Label(frame_paiement, text="💰 Monnaie donnee (Ar) :", font=("Segoe UI", 12, "bold"), bg=BG, fg=TEXTE).grid(row=0, column=0, padx=5)
entry_monnaie = tk.Entry(frame_paiement, width=15, font=("Segoe UI", 13, "bold"), justify="center")
entry_monnaie.grid(row=0, column=1, padx=5)

tk.Button(frame_paiement, text="💵 Calculer le rendu", command=lambda: calculer_rendu(), bg=BTN_BLEU, fg="white", font=("Segoe UI", 11, "bold"), bd=0, padx=15, pady=6, cursor="hand2").grid(row=0, column=2, padx=10)

lbl_rendu = tk.Label(frame_paiement, text="Monnaie a rendre : --", font=("Segoe UI", 16, "bold"), fg=TEXTE, bg=BG)
lbl_rendu.grid(row=1, column=0, columnspan=3, pady=12)

def calculer_rendu():
    try:
        donnee = float(entry_monnaie.get().replace(",", ".").replace(" ", ""))
    except ValueError:
        messagebox.showerror("Erreur", "Entrez un montant valide.")
        return
    total = total_panier()
    if total == 0:
        messagebox.showinfo("Info", "Le panier est vide.")
        return
    rendu = donnee - total
    if rendu < 0:
        lbl_rendu.config(text=f"❌ Il manque {fmt(-rendu)}", fg="#e74c3c")
    else:
        lbl_rendu.config(text=f"✅ Monnaie a rendre : {fmt(rendu)}", fg="#2ecc71")

# --- Ajouter un produit ---
frame_ajout = tk.LabelFrame(root, text="📦 Ajouter un nouveau produit", font=("Segoe UI", 11, "bold"), bg=BG2, fg=TEXTE, bd=2, relief="groove")
frame_ajout.pack(pady=10, padx=20, fill="x")

tk.Label(frame_ajout, text="Nom :", bg=BG2, fg=TEXTE, font=("Segoe UI", 11)).grid(row=0, column=0, padx=5, pady=8)
entry_nom = tk.Entry(frame_ajout, width=20, font=("Segoe UI", 11))
entry_nom.grid(row=0, column=1, padx=5)

tk.Label(frame_ajout, text="Prix (Ar) :", bg=BG2, fg=TEXTE, font=("Segoe UI", 11)).grid(row=0, column=2, padx=5)
entry_prix = tk.Entry(frame_ajout, width=12, font=("Segoe UI", 11))
entry_prix.grid(row=0, column=3, padx=5)

def ajouter_produit():
    nom = entry_nom.get().strip()
    try:
        prix = float(entry_prix.get().replace(",", ".").replace(" ", ""))
    except ValueError:
        messagebox.showerror("Erreur", "Prix invalide.")
        return
    if not nom or prix < 0:
        messagebox.showerror("Erreur", "Nom ou prix invalide.")
        return
    produits[nom] = prix
    sauvegarder_produits(produits)
    combo["values"] = sorted(produits.keys())
    entry_nom.delete(0, tk.END)
    entry_prix.delete(0, tk.END)
    messagebox.showinfo("OK", f"'{nom}' ajoute a la base de donnees.")

tk.Button(frame_ajout, text="✅ Ajouter", command=ajouter_produit, bg=BTN_ORANGE, fg="white", font=("Segoe UI", 11, "bold"), bd=0, padx=15, pady=6, cursor="hand2").grid(row=0, column=4, padx=10, pady=8)

def modifier_prix():
    nom = combo.get()
    if nom not in produits:
        messagebox.showerror("Erreur", "Selectionnez d'abord un produit dans la liste en haut.")
        return
    nouveau = simpledialog.askfloat("Modifier le prix", f"Nouveau prix de '{nom}' (Ar) :", minvalue=0, parent=root)
    if nouveau is not None:
        produits[nom] = nouveau
        sauvegarder_produits(produits)
        afficher_prix()
        messagebox.showinfo("OK", f"Prix de '{nom}' modifie : {fmt(nouveau)}")

tk.Button(frame_ajout, text="✏️ Modifier prix", command=modifier_prix, bg="#8e44ad", fg="white", font=("Segoe UI", 11, "bold"), bd=0, padx=15, pady=6, cursor="hand2").grid(row=0, column=5, padx=10, pady=8)

root.mainloop()
