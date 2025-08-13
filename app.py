# app.py
# Embedding Similarity Playground with keyword extraction + compact thumbnails w/ expanders + threshold (persistent)
# Run: streamlit run app.py

import io
import re
import math
import time
import warnings
from typing import List, Tuple, Optional

import numpy as np
import streamlit as st
import matplotlib.pyplot as plt
from sentence_transformers import SentenceTransformer
from keybert import KeyBERT
from sklearn.decomposition import PCA

warnings.filterwarnings("ignore", category=UserWarning)


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


def _unit(v: np.ndarray) -> np.ndarray:
    n = np.linalg.norm(v)
    return v if n == 0 else v / n


def euclidean_to_similarity(v1: np.ndarray, v2: np.ndarray) -> float:
    dist = float(np.linalg.norm(v1 - v2))
    return 1.0 / (1.0 + dist)


def compute_similarity(
    emb1: np.ndarray, emb2: np.ndarray, metric: str, already_unit: bool = True
) -> float:
    # Normalize if needed
    v1 = emb1 if already_unit else _unit(emb1)
    v2 = emb2 if already_unit else _unit(emb2)

    if metric == "Cosine":
        return float(np.dot(v1, v2))  # for unit vectors, cosine == dot
    elif metric == "Dot product":
        return float(np.dot(v1, v2))
    elif metric == "Euclidean→similarity":
        return euclidean_to_similarity(v1, v2)
    else:
        raise ValueError("Unknown metric")


def extract_keywords_kwbert(
    kw_model: KeyBERT, text: str, top_k: int, ngram_min: int, ngram_max: int
) -> List[Tuple[str, float]]:
    # Returns list of (phrase, score); higher score = more relevant
    candidates = kw_model.extract_keywords(
        text,
        keyphrase_ngram_range=(ngram_min, ngram_max),
        stop_words="english",
        use_maxsum=False,
        use_mmr=True,  # a bit more diverse
        diversity=0.5,
        top_n=top_k,
    )
    return candidates


def fig_to_png_bytes(fig, dpi=150) -> bytes:
    """Convert a Matplotlib figure to PNG bytes and close the figure to free memory."""
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=dpi, bbox_inches="tight")
    plt.close(fig)
    buf.seek(0)
    return buf.getvalue()


# Unified thumbnail + expander renderer for consistent UX
def show_thumb_with_expander(
    png_bytes: bytes, caption: str, filename: str, thumb_width: int = None
):
    """
    Renders a thumbnail (container width by default) and provides
    a 'View full size' expander with a download button.
    """
    if thumb_width is None:
        st.image(png_bytes, caption=caption, use_container_width=True)
    else:
        st.image(png_bytes, caption=caption, width=thumb_width)
    with st.expander("View full size"):
        st.image(png_bytes)
        st.download_button("Download PNG", data=png_bytes, file_name=filename, mime="image/png")


# -----------------------------
# Plotting (return figures; caller decides how to render)
# -----------------------------
def plot_polar(v1: np.ndarray, v2: np.ndarray, title: str):
    # Normalize and compute angle
    v1 = _unit(v1)
    v2 = _unit(v2)
    cos_sim = float(np.dot(v1, v2))
    cos_sim = max(min(cos_sim, 1.0), -1.0)
    theta = math.degrees(math.acos(cos_sim))

    # Anchor v1 at 0 rad; place v2 at arccos(cos) — only the relative angle matters
    fig = plt.figure(figsize=(3.6, 3.0))
    ax = fig.add_subplot(111, projection="polar")
    ax.set_title(f"{title}\ncos = {cos_sim:.4f}  ·  angle = {theta:.1f}°", pad=14)

    # arrows (length 1)
    ax.arrow(0, 0, 0, 1, width=0.01)
    ax.arrow(math.acos(cos_sim), 0, 0, 1, width=0.01)

    ax.set_rmax(1.0)
    ax.set_rticks([0.5, 1.0])
    ax.set_theta_zero_location("E")
    ax.set_theta_direction(-1)
    return fig


def top_contrib_bars(v1: np.ndarray, v2: np.ndarray, title: str, topn: int = 20):
    v1 = _unit(v1)
    v2 = _unit(v2)
    contrib = v1 * v2  # elementwise product; positives help cosine, negatives oppose
    idx = np.argsort(np.abs(contrib))[-topn:]
    idx = idx[np.argsort(contrib[idx])]  # sorted so negatives first
    vals = contrib[idx]

    fig, ax = plt.subplots(figsize=(3.6, 3.0))
    ax.bar(range(len(vals)), vals)
    ax.set_title(title + " — elementwise products (top |value|)", fontsize=10)
    ax.set_xticks([])
    ax.axhline(0, linewidth=0.8)
    return fig


def pca_history_plot_return_fig(history: List[dict]):
    st.markdown("### 🗺️ History Map (PCA → 2D)")
    points = []
    labels = []  # tuples like ("scraped"|"query"|"scraped_kw"|"query_kw", timestamp)

    for h in history:
        if h.get("v_scraped") is None or h.get("v_query") is None:
            continue
        points.append(h["v_scraped"])
        labels.append(("scraped", h["time"]))
        points.append(h["v_query"])
        labels.append(("query", h["time"]))
        if h.get("v_scraped_kw") is not None and h.get("v_query_kw") is not None:
            points.append(h["v_scraped_kw"])
            labels.append(("scraped_kw", h["time"]))
            points.append(h["v_query_kw"])
            labels.append(("query_kw", h["time"]))

    if len(points) < 3:
        st.info("Add a few runs to populate the history map.")
        return None

    X = np.vstack(points).astype(np.float32)
    X = X / (np.linalg.norm(X, axis=1, keepdims=True) + 1e-12)
    pca = PCA(n_components=2, random_state=0)
    XY = pca.fit_transform(X)

    fig, ax = plt.subplots(figsize=(4.0, 4.0))  # smaller thumbnail-friendly base size
    kinds = {"scraped": "o", "query": "^", "scraped_kw": "s", "query_kw": "D"}

    for (kind, _t), (x, y) in zip(labels, XY):
        ax.scatter(x, y, marker=kinds.get(kind, "o"), alpha=0.85)

    ax.set_title("Recent vectors projected to 2D (PCA)", fontsize=10)
    ax.set_xlabel("PC1")
    ax.set_ylabel("PC2")

    # Highlight latest pair(s) with a ring
    latest = history[0]
    latest_pts = [latest["v_scraped"], latest["v_query"]]
    if latest.get("v_scraped_kw") is not None and latest.get("v_query_kw") is not None:
        latest_pts += [latest["v_scraped_kw"], latest["v_query_kw"]]
    latest_pts = np.vstack(latest_pts)
    latest_xy = pca.transform(latest_pts)
    ax.scatter(
        latest_xy[:, 0], latest_xy[:, 1], edgecolor="k", s=160, facecolor="none", linewidth=1.2
    )
    return fig


# -----------------------------
# UI & state
# -----------------------------
st.set_page_config(page_title="Embedding Similarity Playground", page_icon="🧠", layout="wide")
st.title("🧠 Embedding Similarity Playground")

# persistent defaults
if "history" not in st.session_state:
    st.session_state.history = []
if "last" not in st.session_state:
    st.session_state.last = None
if "threshold" not in st.session_state:
    st.session_state.threshold = 0.75

with st.sidebar:
    st.header("Settings")

    model_name = st.selectbox(
        "Embedding model",
        [
            "sentence-transformers/all-MiniLM-L6-v2",
            "sentence-transformers/all-mpnet-base-v2",
        ],
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

run = st.button("Compute similarity", type="primary")


# -----------------------------
# Engine load (lazy & cached)
# -----------------------------
@st.cache_resource(show_spinner=False)
def load_models(selected_model: str):
    embedder = SentenceTransformer(selected_model)
    kw_model = KeyBERT(model=embedder)  # share the same SBERT under the hood
    return embedder, kw_model


# -----------------------------
# Compute on button press; store in session_state.last
# -----------------------------
if run:
    if not scraped or not query:
        st.warning("Please enter both sentences.")
    else:
        with st.spinner("Computing…"):
            embedder, kwbert = load_models(model_name)

            # Preprocess
            p_scraped = preprocess(scraped, do_lower, do_strip)
            p_query = preprocess(query, do_lower, do_strip)

            # Embeddings for full sentences (normalize=True yields unit vectors)
            v_scraped = embedder.encode(p_scraped, normalize_embeddings=True)
            v_query = embedder.encode(p_query, normalize_embeddings=True)

            full_sim = compute_similarity(v_scraped, v_query, metric, already_unit=True)

            # Keyword extraction (optional)
            kw_scraped = []
            kw_query = []
            kw_sim: Optional[float] = None
            v_scraped_kw = None
            v_query_kw = None

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
                kw_sim = compute_similarity(v_scraped_kw, v_query_kw, metric, already_unit=True)

            # save "last" result for persistent display
            st.session_state.last = {
                "time": time.strftime("%H:%M:%S"),
                "model": model_name,
                "metric": metric,
                "scraped": scraped,
                "query": query,
                "p_scraped": p_scraped,
                "p_query": p_query,
                "full_sim": full_sim,
                "kw_sim": kw_sim,
                "kw_scraped": kw_scraped,
                "kw_query": kw_query,
                "v_scraped": v_scraped.astype(np.float32),
                "v_query": v_query.astype(np.float32),
                "v_scraped_kw": None if v_scraped_kw is None else v_scraped_kw.astype(np.float32),
                "v_query_kw": None if v_query_kw is None else v_query_kw.astype(np.float32),
            }

            # update history
            st.session_state.history.insert(
                0,
                {
                    "time": st.session_state.last["time"],
                    "model": model_name,
                    "metric": metric,
                    "scraped": scraped,
                    "query": query,
                    "full_sim": full_sim,
                    "kw_sim": kw_sim,
                    "v_scraped": st.session_state.last["v_scraped"],
                    "v_query": st.session_state.last["v_query"],
                    "v_scraped_kw": st.session_state.last["v_scraped_kw"],
                    "v_query_kw": st.session_state.last["v_query_kw"],
                },
            )
            st.session_state.history = st.session_state.history[:50]

# -----------------------------
# Results & visuals (render from st.session_state.last)
# -----------------------------
last = st.session_state.last
if last is not None:
    st.subheader("Results")
    m1, m2, m3 = st.columns([1, 1, 1])

    with m1:
        st.metric("Full-sentence similarity", f"{last['full_sim']:.4f}")

    if last["kw_sim"] is not None:
        delta = last["kw_sim"] - last["full_sim"]
        with m2:
            st.metric("Keyword-only similarity", f"{last['kw_sim']:.4f}", delta=f"{delta:+.4f}")

    with m3:
        st.write("**Model:**", last["model"].split("/")[-1])
        st.write("**Metric:**", last["metric"])

    # Threshold slider (persistent key, outside button block)
    threshold = st.slider(
        "Match threshold",
        min_value=0.0,
        max_value=1.0,
        step=0.01,
        key="threshold",
        help="Scores at or above this value are considered a 'match'.",
    )

    def label_for(score: Optional[float], th: float) -> str:
        if score is None:
            return "—"
        if score >= th:
            return "✅ Likely match"
        elif score >= th - 0.10:
            return "⚠️ Borderline"
        else:
            return "❌ No match"

    st.write(f"**Classification (full sentence):** {label_for(last['full_sim'], threshold)}")
    if last["kw_sim"] is not None:
        st.write(f"**Classification (keyword-only):** {label_for(last['kw_sim'], threshold)}")

    st.markdown("#### Inputs (post-preprocessing)")
    a, b = st.columns(2)
    with a:
        st.code(last["p_scraped"], language="text")
    with b:
        st.code(last["p_query"], language="text")

    if last["kw_scraped"] or last["kw_query"]:
        st.markdown("#### Extracted Keywords (KeyBERT)")
        c1, c2 = st.columns(2)
        with c1:
            st.write("**Scraped sentence keywords**")
            for k, s in last["kw_scraped"]:
                st.write(f"- {k}  ·  score={s:.3f}")
        with c2:
            st.write("**Query sentence keywords**")
            for k, s in last["kw_query"]:
                st.write(f"- {k}  ·  score={s:.3f}")

    # -----------------------------
    # Visuals row (current-run visuals only)
    # -----------------------------
    st.markdown("### Visuals (full sentence)")
    colA, colB = st.columns(2)  # just two columns now

    # Polar (full sentence)
    fig_polar_full = plot_polar(last["v_scraped"], last["v_query"], "Full-sentence vectors")
    png_polar_full = fig_to_png_bytes(fig_polar_full)
    with colA:
        show_thumb_with_expander(
            png_polar_full, "Polar (full sentence)", "polar_full.png", thumb_width=200
        )

    # Contributions (full sentence)
    fig_contrib_full = top_contrib_bars(
        last["v_scraped"], last["v_query"], "Full-sentence", topn=20
    )
    png_contrib_full = fig_to_png_bytes(fig_contrib_full)
    with colB:
        show_thumb_with_expander(
            png_contrib_full,
            "Top contributions (full sentence)",
            "contrib_full.png",
            thumb_width=300,
        )

    # Optional: Keyword-only row
    if last["v_scraped_kw"] is not None and last["v_query_kw"] is not None:
        st.markdown("### Visuals (Keyword-only)")
        k1, k2 = st.columns(2)

        fig_polar_kw = plot_polar(last["v_scraped_kw"], last["v_query_kw"], "Keyword-only vectors")
        png_polar_kw = fig_to_png_bytes(fig_polar_kw)
        with k1:
            show_thumb_with_expander(
                png_polar_kw, "Polar (keyword-only)", "polar_keyword.png", thumb_width=200
            )

        fig_contrib_kw = top_contrib_bars(
            last["v_scraped_kw"], last["v_query_kw"], "Keyword-only", topn=20
        )
        png_contrib_kw = fig_to_png_bytes(fig_contrib_kw)
        with k2:
            show_thumb_with_expander(
                png_contrib_kw,
                "Top contributions (keyword-only)",
                "contrib_keyword.png",
                thumb_width=300,
            )

# -----------------------------
# History Visual (PCA) — its own row, above the History table
# -----------------------------
st.markdown("### History Visual")
fig_pca = pca_history_plot_return_fig(st.session_state.history)
if fig_pca is None:
    st.info("Run a few comparisons to populate the history map.")
else:
    png_pca = fig_to_png_bytes(fig_pca, dpi=200)
    show_thumb_with_expander(png_pca, "History map (PCA)", "history_map.png", thumb_width=200)

# -----------------------------
# History table
# -----------------------------
if st.session_state.history:
    st.markdown("### History (last 50)")
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
