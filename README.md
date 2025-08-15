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
- **NEW:** Automatic commit message generation via AI
  (local Ollama, OpenAI, or Anthropic — selectable with one `make` command).

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
- **AI Commit Messages**:
  - Generates commit messages automatically using the AI backend of your choice.
  - Appends `AI-Commit: <backend> <model>` to each message.
  - You can still edit the AI-generated message before committing.

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

🚀 Quick Start
1. Clone the repo
git clone https://github.com/mdcrotu/Embedding-Playground.git
cd embedding-playground

2. Install dependencies
Option A — uv (recommended)
curl -LsSf https://astral.sh/uv/install.sh | sh
make install

Option B — dev.sh auto-installer
chmod +x dev.sh
./dev.sh run

Option C — pip + venv
python3 -m venv .venv
source .venv/bin/activate  # or .venv\Scripts\activate on Windows
pip install -r requirements.txt

▶️ Running the App
make run

Or with dev.sh:
./dev.sh run

Streamlit will start and open a browser window (default: http://localhost:8501).

🤖 AI Commit Message Setup

The project includes a prepare-commit-msg hook that uses AI to generate commit messages.
You can choose your backend:
| Command               | Backend           | Requirements                                   |
| --------------------- | ----------------- | ---------------------------------------------- |
| `make hook-ollama`    | Ollama (local)    | [Ollama](https://ollama.com) installed locally |
| `make hook-openai`    | OpenAI (cloud)    | `OPENAI_API_KEY` set in env                    |
| `make hook-anthropic` | Anthropic (cloud) | `ANTHROPIC_API_KEY` set in env                 |

To see what backend is currently active:
make hook-show

Notes:
If you run git commit -m "...", the hook is skipped — no AI generation.
If you run git commit without -m, the AI-generated message appears in your editor so you can review/edit it.
The generated commit message always includes an AI-Commit: line at the bottom with the backend and model.


🧹 Formatting & Linting
Black — Python code formatter.
Ruff — Fast linter & auto-fixer.
pre-commit — Runs these before each commit.

Install all hooks (without setting an AI backend):
make hooks

Run checks manually:
make fmt

📂 Project Structure
.
├── app.py                   # Streamlit app with visuals
├── dev.sh                   # First-time setup helper (installs uv if needed)
├── Makefile                  # Task runner (prefers uv, falls back to pip)
├── pyproject.toml            # Project metadata & dependencies
├── requirements.txt          # Alternative dep file for pip
├── uv.lock                   # uv lockfile for reproducible installs
├── .pre-commit-config.yaml   # Pre-commit hook config
├── .env.ai                   # AI backend settings (created by make hook-*)
└── README.md

⚙️ Commands Cheat Sheet
| Command                  | Description                           |
| ------------------------ | ------------------------------------- |
| **Core**                 |                                       |
| `make install`           | Install dependencies                  |
| `make run`               | Run the Streamlit app                 |
| **AI Commit Hooks**      |                                       |
| `make hook-ollama`       | Use Ollama for AI commit messages     |
| `make hook-openai`       | Use OpenAI for AI commit messages     |
| `make hook-anthropic`    | Use Anthropic for AI commit messages  |
| `make hook-show`         | Show current AI backend settings      |
| **Formatting & Linting** |                                       |
| `make fmt`               | Run all pre-commit hooks on all files |
| `make format`            | Run Black + Ruff format only          |
| `make lint`              | Ruff check only                       |
| `make format-all`        | Format + run hooks                    |
| **Maintenance**          |                                       |
| `make clean`             | Remove venv and caches                |
| `make check`             | Alias for `make fmt`                  |

📷 Screenshots (Example)
Polar Vector Plot
PCA History Map
Top-Dimension Contribution Bars

📜 License

MIT License — do whatever you like, attribution appreciated.

---

If you want, I can also add a **“Troubleshooting”** section that covers:
- What happens if `.env.ai` is missing.
- How to bypass the hook temporarily.
- Why `git commit -m` skips AI generation.

Do you want me to add that too? That way future-you won’t have to re-learn it later.
