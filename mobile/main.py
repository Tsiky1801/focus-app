# Version mobile (Kivy) de la caisse magasin
import json
import os
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput
from kivy.uix.spinner import Spinner
from kivy.graphics import Color, Rectangle

DB_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "produits.json")

PRODUITS_DEFAUT = {
    "Eau minerale 0.5L": 500, "Pain": 1200, "Lait 1L": 3000,
    "Coca Cola 1.5L": 4500, "Croissant": 800, "Cafe": 2500,
    "Chocolat": 3500, "Yaourt": 700,
}

def charger_produits():
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return dict(PRODUITS_DEFAUT)
    return dict(PRODUITS_DEFAUT)

def sauvegarder_produits(produits):
    with open(DB_FILE, "w", encoding="utf-8") as f:
        json.dump(produits, f, ensure_ascii=False, indent=2)

produits = charger_produits()
panier = []

def fmt(m):
    return f"{m:,.0f} Ar".replace(",", " ")

class CaisseApp(App):
    def build(self):
        root = BoxLayout(orientation="vertical", padding=10, spacing=8)
        with root.canvas.before:
            Color(30/255, 42/255, 56/255, 1)
            self.rect = Rectangle(size=root.size, pos=root.pos)
        root.bind(size=lambda *a: setattr(self.rect, "size", root.size))
        root.bind(pos=lambda *a: setattr(self.rect, "pos", root.pos))

        root.add_widget(Label(text="🛒 CAISSE MAGASIN", font_size=26, bold=True, size_hint_y=0.08, color=(0.95,0.77,0.06,1)))

        # Choix produit
        self.spinner = Spinner(text="Choisir un produit", values=sorted(produits.keys()), size_hint_y=0.08, font_size=18)
        self.spinner.bind(text=self.maj_prix)
        root.add_widget(self.spinner)

        self.lbl_prix = Label(text="Prix : --", font_size=20, size_hint_y=0.07, color=(0.18,0.8,0.44,1))
        root.add_widget(self.lbl_prix)

        ligne_qte = BoxLayout(size_hint_y=0.08, spacing=5)
        ligne_qte.add_widget(Label(text="Quantite :", font_size=18))
        self.qte = TextInput(text="1", input_filter="int", font_size=20, multiline=False, size_hint_x=0.3)
        ligne_qte.add_widget(self.qte)
        root.add_widget(ligne_qte)

        btn_add = Button(text="➕ Ajouter au panier", font_size=20, background_color=(0.15,0.68,0.38,1), size_hint_y=0.09)
        btn_add.bind(on_press=self.ajouter)
        root.add_widget(btn_add)

        # Liste panier
        self.lbl_panier = Label(text="Panier vide", font_size=16, size_hint_y=0.2, color=(1,1,1,1), valign="top")
        self.lbl_panier.bind(size=lambda w, v: setattr(w, "text_size", v))
        root.add_widget(self.lbl_panier)

        btn_vider = Button(text="🗑 Vider le panier", font_size=18, background_color=(0.9,0.3,0.24,1), size_hint_y=0.08)
        btn_vider.bind(on_press=self.vider)
        root.add_widget(btn_vider)

        self.lbl_total = Label(text="TOTAL : 0 Ar", font_size=26, bold=True, size_hint_y=0.08, color=(0.95,0.77,0.06,1))
        root.add_widget(self.lbl_total)

        # Paiement
        ligne = BoxLayout(size_hint_y=0.08, spacing=5)
        ligne.add_widget(Label(text="Monnaie donnee (Ar) :", font_size=16))
        self.monnaie = TextInput(text="", input_filter="float", font_size=20, multiline=False)
        ligne.add_widget(self.monnaie)
        root.add_widget(ligne)

        btn_calc = Button(text="💵 Calculer le rendu", font_size=20, background_color=(0.16,0.5,0.73,1), size_hint_y=0.09)
        btn_calc.bind(on_press=self.calculer)
        root.add_widget(btn_calc)

        self.lbl_rendu = Label(text="Monnaie a rendre : --", font_size=24, bold=True, size_hint_y=0.1)
        root.add_widget(self.lbl_rendu)

        # Nouveau produit
        self.new_nom = TextInput(hint_text="Nom du nouveau produit", font_size=16, size_hint_y=0.08, multiline=False)
        root.add_widget(self.new_nom)
        self.new_prix = TextInput(hint_text="Prix (Ar)", input_filter="float", font_size=16, size_hint_y=0.08, multiline=False)
        root.add_widget(self.new_prix)
        btn_new = Button(text="✅ Ajouter ce produit", font_size=18, background_color=(0.95,0.61,0.07,1), size_hint_y=0.09)
        btn_new.bind(on_press=self.ajouter_produit)
        root.add_widget(btn_new)

        return root

    def maj_prix(self, spinner, texte):
        if texte in produits:
            self.lbl_prix.text = f"Prix : {fmt(produits[texte])}"

    def ajouter(self, _):
        nom = self.spinner.text
        if nom in produits:
            try:
                q = int(self.qte.text or "1")
            except ValueError:
                q = 1
            panier.append((nom, produits[nom], q))
            self.rafraichir()

    def vider(self, _):
        panier.clear()
        self.rafraichir()
        self.lbl_rendu.text = "Monnaie a rendre : --"

    def rafraichir(self):
        lignes = [f"{n}  {q} x {fmt(p)} = {fmt(p*q)}" for n, p, q in panier]
        self.lbl_panier.text = "\n".join(lignes) if lignes else "Panier vide"
        total = sum(p*q for _, p, q in panier)
        self.lbl_total.text = f"TOTAL : {fmt(total)}"

    def calculer(self, _):
        try:
            donnee = float(self.monnaie.text.replace(" ", "").replace(",", "."))
        except ValueError:
            self.lbl_rendu.text = "Entrez un montant valide"
            return
        total = sum(p*q for _, p, q in panier)
        rendu = donnee - total
        if rendu < 0:
            self.lbl_rendu.text = f"❌ Il manque {fmt(-rendu)}"
        else:
            self.lbl_rendu.text = f"✅ A rendre : {fmt(rendu)}"

    def ajouter_produit(self, _):
        nom = self.new_nom.text.strip()
        try:
            prix = float(self.new_prix.text.replace(" ", "").replace(",", "."))
        except ValueError:
            return
        if nom and prix >= 0:
            produits[nom] = prix
            sauvegarder_produits(produits)
            self.spinner.values = sorted(produits.keys())
            self.new_nom.text = ""
            self.new_prix.text = ""

if __name__ == "__main__":
    CaisseApp().run()
