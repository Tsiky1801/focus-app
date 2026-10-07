import streamlit as st
import urllib.request
import urllib.parse

st.set_page_config(page_title="Mon IA", page_icon="🤖")
st.title("🤖 Mon Assistant IA")
st.write("Pose une question, l'IA te répond (gratuit, sans compte).")

question = st.text_area("Ta question :")

if st.button("Envoyer"):
    if not question:
        st.warning("Écris une question !")
    else:
        with st.spinner("L'IA réfléchit... 🤔"):
            try:
                url = "https://text.pollinations.ai/" + urllib.parse.quote(question)
                r = urllib.request.urlopen(url, timeout=90)
                reponse = r.read().decode("utf-8", errors="ignore")
                st.success(reponse)
            except Exception as e:
                st.error(f"Erreur : {e}")
