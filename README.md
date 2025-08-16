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
---
## ▶️ Running the App
```bash
make run
```
Or with dev.sh:
```bash
./dev.sh run
```
Streamlit will start and open a browser window (default: http://localhost:8501).


---
## 🤖 AI Commit Message Setup

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

---
## 🧹 Formatting & Linting
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
---
## 📂 Project Structure
```bash
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
```
---
## ⚙️ Commands Cheat Sheet
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

---
## 🛠 Troubleshooting
#### 1. If .env.ai is missing

The AI commit hook relies on .env.ai to know which backend/model to use.
If it’s missing, the hook will usually fail silently (or just leave your commit message unchanged).

Fix: Re-run one of the backend setup commands:
```bash
make hook-ollama
# or
make hook-openai
# or
make hook-anthropic
```
This will regenerate .env.ai with the correct backend settings.

#### 2. Skipping the AI hook
Sometimes you don’t want to wait for the AI or you want to write your own message.
- Bypass the hook completely:
```bash
git commit -m "your message here" --no-verify
```
(--no-verify skips all pre-commit hooks, not just AI.)

- Write your own message normally:
```bash
git commit -m "your message here"
```
If you pass -m, the hook is skipped — your message is used as-is.

#### 3. Why git commit -m skips AI generation

When you use:
```bash
git commit -m "message"
```
Git never opens the commit message buffer (.git/COMMIT_EDITMSG). Since our hook is a prepare-commit-msg hook that modifies that buffer, it doesn’t get a chance to run.

That’s expected behavior.
If you want the AI to generate a commit message you can review/edit, just run:
```bash
git commit
```
(with no -m). Git opens your editor, the hook injects the AI-generated message, and you can edit it before saving.

#### 4. Debugging the hook

If the hook doesn’t seem to run:
- Make sure .git/hooks/prepare-commit-msg exists and is executable.
- Add set -x at the top of ai_commit_msg.sh to print debug output.
- Check the log files (if enabled) in .git/hooks/ like _ai_commit.log.

---
## ❓ FAQ
**Why does git commit open my editor first?**

That’s just how Git works — it always opens the commit message buffer (.git/COMMIT_EDITMSG) unless you pass -m.

Our hook edits that buffer before the editor opens, so you see the AI-generated message pre-filled, ready for you to edit.

---
**Why does git commit -m "msg" skip the AI?**

Because with -m, Git never opens .git/COMMIT_EDITMSG. The AI hook only runs when there’s a buffer to modify.
If you want AI, just run git commit without -m.

---
**Where is the AI commit message stored?**
- Temporary files: .git/hooks/_ai_* (diff, payload, logs).

- Final commit message: .git/COMMIT_EDITMSG.
That’s what Git reads when you save and exit your editor.

---
**How do I change the default AI model?**

Edit .env.ai in your repo root:
```bash
AI_BACKEND=openai
OPENAI_MODEL=gpt-4o-mini
```
(or set it to ollama / anthropic).
Then re-run:
```bash
make hook-openai
```
(or hook-ollama, etc.)

---
**How do I temporarily bypass the AI?**

Use:
```bash
git commit -m "your message" --no-verify
```
That skips all hooks. Or just pass -m to skip AI but still run lint/format hooks.

---
**How do I know which AI backend was used?**

Every generated message ends with a trailer like:
```makefile
AI-Commit: openai gpt-4o-mini
```
So you can see it in git log later.

---
**Can I re-run the AI on an old commit?**

Yep — just edit the commit:
```bash
git commit --amend
```
The hook will generate a new message, and you can replace the old one.

---
## 📷 Screenshots (Example)
**Polar Vector Plot**

**PCA History Map**

**Top-Dimension Contribution Bars**


---
## 📜 License

MIT License — do whatever you like, attribution appreciated.

---
