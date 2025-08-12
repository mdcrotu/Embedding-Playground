# 🧠 Embedding Similarity Playground

An interactive **Streamlit app** for experimenting with **sentence embeddings**, **cosine similarity**, and **keyword extraction**.

You can:
- Compare **full-sentence** similarity vs. **keyword-only** similarity.
- Extract top keywords using [KeyBERT](https://github.com/MaartenGr/KeyBERT).
- Toggle preprocessing (lowercasing, punctuation stripping).
- Try different embedding models and similarity metrics.
- See how small text changes affect similarity scores.
- Keep a history of your last comparisons.

---

## ✨ Features

- **Two text inputs**: "Scraped Sentence" (source text) and "Query Sentence" (test text).
- **Model selector**: Choose from different `sentence-transformers` models.
- **Similarity metrics**: Cosine, dot product, and Euclidean→similarity.
- **Keyword extraction**: Compare similarity on extracted keywords only.
- **History log**: See your last 20 comparisons.
- **Preprocessing toggles**: Lowercase, strip punctuation.
- **Auto-install helper**: `dev.sh` script for easy first-time setup.

---

## 📦 Requirements

- Python **3.9+**
- [uv](https://docs.astral.sh/uv/) **(preferred)** or `pip`
- Git

---

## 🚀 Quick Start

### **1. Clone the repo**
```bash
git clone https://github.com/mdcrotu/Embedding-Playground.git
cd Embedding-Playground
