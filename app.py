import re
import time
import numpy as np
import streamlit as st
from sentence_transformers import SentenceTransformer, util
from keybert import KeyBERT


# -----------------------------
# Utilities
# -----------------------------
def preprocess(text: str, lower: bool, strip_punct: bool) -> str:
    if lower:
        text = text.lower()
    if strip_punct:
        text = re.sub(r"[^\w\s]", " ", text)
        text = re.sub(r"\s+", " ", text).strip()
    return text


def euclidean_to_similarity(v1: np.ndarray, v2: np.ndarray) -> float:
    # Map Euclidean distance to a bounded similarity for display:
    # sim = 1 / (1 + distance)
    dist = np.linalg.norm(v1 - v2)
    return float(1.0 / (1.0 + dist))


def compute_similarity(emb1: np.ndarray, emb2: np.ndarray, metric: str) -> float:
    if metric == "Cosine":
        return float(util.cos_sim(emb1, emb2).item())
    elif metric == "Dot product":
        return float(np.dot(emb1, emb2))
    elif metric == "Euclidean→similarity":
        return euclidean_to_similarity(emb1, emb2)
    else:
        raise ValueError("Unknown metric")


def extract_keywords_kwbert(
    kw_model: KeyBERT, text: str, top_k: int, ngram_min: int, ngram_max: int
):
    candidates = kw_model.extract_keywords(
        text,
        keyphrase_ngram_range=(ngram_min, ngram_max),
        stop_words="english",
        use_maxsum=False,
        use_mmr=True,  # increases diversity a bit
        diversity=0.5,
        top_n=top_k,
    )
    # candidates is list of (phrase, score). Higher score = more relevant.
    return candidates


# -----------------------------
# UI
# -----------------------------
st.set_page_config(page_title="Embedding Similarity Playground", page_icon="🧠", layout="wide")
st.title("🧠 Embedding Similarity Playground")

with st.sidebar:
    st.header("Settings")
    model_name = st.selectbox(
        "Embedding model",
        ["sentence-transformers/all-MiniLM-L6-v2", "sentence-transformers/all-mpnet-base-v2"],
        index=0,
    )
    metric = st.selectbox(
        "Similarity metric", ["Cosine", "Dot product", "Euclidean→similarity"], index=0
    )

    st.subheader("Preprocessing")
    do_lower = st.checkbox("lowercase", value=True)
    do_strip = st.checkbox("strip punctuation", value=False)

    st.subheader("Keyword Extraction (KeyBERT)")
    enable_kw = st.checkbox("Enable keyword extraction", value=True)
    top_k = st.slider("Top K keywords", min_value=3, max_value=20, value=8, step=1)
    ngram_min, ngram_max = st.select_slider(
        "n-gram range",
        options=[1, 2, 3],
        value=(1, 2),
        help="Min and max n-grams for candidate phrases",
    )

    st.caption(
        "Tip: Compare full-sentence vs keyword-only similarity to see how salience affects the score."
    )

col1, col2 = st.columns(2)
with col1:
    scraped = st.text_area(
        "Scraped sentence (from a website)",
        height=140,
        placeholder="e.g., DVT Eclipse IDE lets you trace signal drivers across hierarchy using the Signals view…",
    )
with col2:
    query = st.text_area(
        "Query sentence (what the user asks)",
        height=140,
        placeholder="e.g., How do I follow a net's drivers through modules in DVT?",
    )

if "history" not in st.session_state:
    st.session_state.history = []

run = st.button("Compute similarity", type="primary")


# -----------------------------
# Engine load (lazy)
# -----------------------------
@st.cache_resource(show_spinner=False)
def load_models(selected_model: str):
    st.spinner("Loading model…")
    embedder = SentenceTransformer(selected_model)
    kw_model = KeyBERT(model=embedder)  # share same SBERT under the hood
    return embedder, kw_model


if run:
    if not scraped or not query:
        st.warning("Please enter both sentences.")
    else:
        with st.spinner("Computing…"):
            embedder, kwbert = load_models(model_name)

            # Preprocess
            p_scraped = preprocess(scraped, do_lower, do_strip)
            p_query = preprocess(query, do_lower, do_strip)

            # Embeddings for full sentences
            v_scraped = embedder.encode(p_scraped, normalize_embeddings=True)
            v_query = embedder.encode(p_query, normalize_embeddings=True)

            full_sim = compute_similarity(v_scraped, v_query, metric)

            # Keyword extraction (optional)
            kw_scraped = []
            kw_query = []
            kw_sim = None

            if enable_kw:
                kw_scraped = extract_keywords_kwbert(kwbert, p_scraped, top_k, ngram_min, ngram_max)
                kw_query = extract_keywords_kwbert(kwbert, p_query, top_k, ngram_min, ngram_max)

                # Build keyword-only “summaries” to re-embed
                text_kw_scraped = " ; ".join([k for k, s in kw_scraped])
                text_kw_query = " ; ".join([k for k, s in kw_query])

                v_scraped_kw = embedder.encode(
                    text_kw_scraped or p_scraped, normalize_embeddings=True
                )
                v_query_kw = embedder.encode(text_kw_query or p_query, normalize_embeddings=True)
                kw_sim = compute_similarity(v_scraped_kw, v_query_kw, metric)

        # -----------------------------
        # Display
        # -----------------------------
        st.subheader("Results")
        m1, m2, m3 = st.columns([1, 1, 1])

        with m1:
            st.metric("Full-sentence similarity", f"{full_sim:.4f}")

        if enable_kw and kw_sim is not None:
            delta = kw_sim - full_sim
            with m2:
                st.metric("Keyword-only similarity", f"{kw_sim:.4f}", delta=f"{delta:+.4f}")

        with m3:
            st.write("**Model:**", model_name)
            st.write("**Metric:**", metric)

        st.markdown("#### Inputs (post-preprocessing)")
        a, b = st.columns(2)
        with a:
            st.code(p_scraped or scraped, language="text")
        with b:
            st.code(p_query or query, language="text")

        if enable_kw:
            st.markdown("#### Extracted Keywords (KeyBERT)")
            c1, c2 = st.columns(2)
            with c1:
                st.write("**Scraped sentence keywords**")
                for k, s in kw_scraped:
                    st.write(f"- {k}  ·  score={s:.3f}")
            with c2:
                st.write("**Query sentence keywords**")
                for k, s in kw_query:
                    st.write(f"- {k}  ·  score={s:.3f}")

        # Save to history
        st.session_state.history.insert(
            0,
            {
                "time": time.strftime("%H:%M:%S"),
                "model": model_name,
                "metric": metric,
                "scraped": scraped,
                "query": query,
                "full_sim": full_sim,
                "kw_sim": kw_sim if enable_kw else None,
            },
        )
        st.session_state.history = st.session_state.history[:20]

if st.session_state.history:
    st.markdown("### History (last 20)")
    st.dataframe(
        [
            {
                "time": h["time"],
                "model": h["model"].split("/")[-1],
                "metric": h["metric"],
                "full_sim": round(h["full_sim"], 4),
                "kw_sim": None if h["kw_sim"] is None else round(h["kw_sim"], 4),
                "scraped": h["scraped"],
                "query": h["query"],
            }
            for h in st.session_state.history
        ]
    )
