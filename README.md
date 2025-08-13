# 🧠 Embedding Similarity Playground

An interactive **Streamlit app** for experimenting with **sentence embeddings**, **cosine similarity**, and **keyword extraction**, now with **visual vector comparisons**.

You can:
- Compare **full-sentence** similarity vs. **keyword-only** similarity.
- Extract top keywords using [KeyBERT](https://github.com/MaartenGr/KeyBERT).
- Toggle preprocessing (lowercasing, punctuation stripping).
- Try different embedding models and similarity metrics.
- See how small text changes affect similarity scores.
- View **graphical representations** of similarity:
  - 📐 **Polar angle plot** showing vector orientation.
  - 🗺 **PCA history map** of recent embeddings.
  - 📊 **Top-dimension contribution bars** for cosine similarity.

---

## ✨ Features

- **Two text inputs**: "Scraped Sentence" and "Query Sentence".
- **Model selector**: Choose from different `sentence-transformers` models.
- **Similarity metrics**: Cosine, dot product, Euclidean→similarity.
- **Keyword extraction**: Compare similarity using extracted keywords.
- **Visualizations**:
  - **Polar plot**: See the angle between vectors (cosine relation).
  - **PCA projection**: 2D map of recent embeddings.
  - **Contribution bars**: Dimension-level similarity contributions.
- **History log**: See your last 50 comparisons.

---

## 📦 Requirements

Python **3.9+** and either:
- **[uv](https://docs.astral.sh/uv/)** (preferred), or
- `pip` and `venv`.

Dependencies:
```python
streamlit>=1.36
sentence-transformers>=3.0
keybert>=0.8
scikit-learn>=1.4
numpy>=1.26
matplotlib>=3.9
```
---

## 🚀 Quick Start

### 1. Clone the repo
```bash
git clone https://github.com/mdcrotu/Embedding-Playground.git
cd embedding-playground
```

2. Install dependencies
Option A — uv (recommended)
```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
make install
```

Option B — dev.sh auto-installer
```bash
chmod +x dev.sh
./dev.sh run
```

Option C — pip + venv
```bash
python3 -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
```
▶️ Running the App
```bash
make run
```
Or with dev.sh:
```bash
./dev.sh run
```
Streamlit will start and open a browser window (default: http://localhost:8501).

🧹 Formatting & Linting
- Black — Python code formatter.
- Ruff — Fast linter & auto-fixer.
- pre-commit — Runs these before each commit.

Install hooks once:
```bash
make hook-install
```
Run checks manually:
```bash
make fmt
```
📂 Project Structure
```bash
.
├── app.py                   # Streamlit app with visuals
├── dev.sh                   # First-time setup helper (installs uv if needed)
├── Makefile                  # Task runner (prefers uv, falls back to pip)
├── pyproject.toml            # Project metadata & dependencies (uv/PEP 621)
├── requirements.txt          # Alternative dep file for pip
├── uv.lock                   # uv lockfile for reproducible installs
├── .pre-commit-config.yaml   # Pre-commit hook config
└── README.md
```
---
## ⚙️ Commands Cheat Sheet
| Command             | Description              |
| ------------------- | ------------------------ |
| `make install`      | Install dependencies     |
| `make run`          | Run the app              |
| `make fmt`          | Run all pre-commit hooks |
| `make hook-install` | Install pre-commit hooks |
| `make clean`        | Remove venv and caches   |
| `make check`        | Run formatters/linters   |
---
## 📷 Screenshots (Example)

### Polar Vector Plot


### PCA History Map


### Top-Dimension Contribution Bars

---

## 📜 License

MIT License — do whatever you like, attribution appreciated.
