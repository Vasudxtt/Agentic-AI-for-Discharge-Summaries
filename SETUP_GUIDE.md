# DischargePilot — Setup & Run Guide

> Complete instructions for running DischargePilot from scratch.  
> Two paths: **Docker** (faster, one command) or **Manual** (more control).

---

## Prerequisites

| Tool | Minimum version | Check command |
|---|---|---|
| Git | any | `git --version` |
| **Docker path only** | | |
| Docker Desktop | 24+ | `docker --version` |
| Docker Compose | v2 | `docker compose version` |
| **Manual path only** | | |
| Python | 3.10+ | `python3 --version` |
| Node.js | 18+ | `node --version` |
| npm | 9+ | `npm --version` |

**Download links:**
- Docker Desktop: https://www.docker.com/products/docker-desktop
- Python: https://www.python.org/downloads
- Node.js (LTS): https://nodejs.org

---

## Step 0 — Get the Code

```bash
# Option A: clone from GitHub
git clone https://github.com/YOUR_USERNAME/discharge-agent.git
cd discharge-agent

# Option B: unzip the download
unzip discharge-agent.zip
cd discharge-agent
```

---

## Step 1 — Configure Environment

```bash
cp .env.example .env
```

Open `.env` in any text editor. The key settings:

### LLM Mode (choose one)

**Option A — Mock mode (no API key, works offline, good for demo)**
```env
MOCK_LLM=true
LLM_PROVIDER=mock
```

**Option B — Anthropic Claude (recommended for production)**
1. Get an API key at https://console.anthropic.com → API Keys → Create Key
```env
MOCK_LLM=false
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-YOUR_KEY_HERE
ANTHROPIC_MODEL=claude-sonnet-4-6
```

**Option C — OpenAI GPT**
1. Get an API key at https://platform.openai.com/api-keys
```env
MOCK_LLM=false
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-YOUR_KEY_HERE
OPENAI_MODEL=gpt-4.1
```

> You can always start with `MOCK_LLM=true` and switch later — just restart the server.

---

## Path A — Docker Setup (Recommended)

> **One command starts everything.** No Python, Node, or OCR installation needed.

### A1 — Build and Start

```bash
docker compose up --build
```

First run downloads ~2 GB of dependencies (Python, OCR model, Node modules).  
Subsequent starts take ~20 seconds.

### A2 — Verify

```
✔ Container discharge-backend  Started  →  http://localhost:8003
✔ Container discharge-frontend Started  →  http://localhost:5173
```

Open http://localhost:5173 in your browser.

### A3 — Stop

```bash
docker compose down
```

### A4 — Useful Docker Commands

```bash
# Rebuild after code changes
docker compose up --build

# View backend logs
docker compose logs -f backend

# View frontend logs
docker compose logs -f frontend

# Run a one-off command inside the backend container
docker compose exec backend python3 data/samples/generate_patient3.py

# Generate sample test PDFs inside Docker
docker compose exec backend python3 data/samples/generate_samples.py
```

### Docker Ports

| Service | Container port | Host port |
|---|---|---|
| Backend (FastAPI) | 8003 | 8003 |
| Frontend (Vite/Nginx) | 80 | 5173 |

To change the host port, edit `docker-compose.yml`:
```yaml
ports:
  - "YOUR_PORT:8003"   # backend
  - "YOUR_PORT:80"     # frontend
```

---

## Path B — Manual Setup

### B1 — Python Virtual Environment

```bash
# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate          # Mac / Linux
.venv\Scripts\Activate.ps1         # Windows PowerShell

# You should see (.venv) in your terminal prompt
```

### B2 — Install Python Packages

```bash
pip install -r backend/requirements.txt
```

Takes 3–5 minutes (EasyOCR downloads a neural network model).

### B3 — Install Tesseract OCR

Tesseract is the fallback OCR engine for scanned PDFs.

**Mac:**
```bash
brew install tesseract
```

**Ubuntu / Debian:**
```bash
sudo apt-get install tesseract-ocr
```

**Windows:**
Download from: https://github.com/UB-Mannheim/tesseract/wiki  
During install, tick "Add to PATH".

Verify:
```bash
tesseract --version
# Should print: tesseract 5.x.x
```

> If you only use typed (non-scanned) PDFs, you can skip Tesseract.

### B4 — Install Frontend Packages

```bash
cd frontend
npm install
cd ..
```

### B5 — Generate Sample Test PDFs (optional)

```bash
python3 data/samples/generate_samples.py    # Patient 1 — NSTEMI
python3 data/samples/generate_patient3.py   # Patient 3 — Heart Failure + AF
```

Files created in `data/samples/Patient_001/` and `data/samples/Patient_003/`.

### B6 — Start the Application

**Option 1 — Start script (starts both together):**
```bash
chmod +x start.sh
./start.sh
```

**Option 2 — Two terminals:**

Terminal 1 — Backend:
```bash
source .venv/bin/activate
PYTHONPATH=. .venv/bin/uvicorn backend.main:app --host 0.0.0.0 --port 8003 --reload
```

Terminal 2 — Frontend:
```bash
cd frontend
npm run dev
```

### B7 — Verify

| URL | Expected response |
|---|---|
| http://localhost:5173 | Main application UI |
| http://localhost:8003/docs | Interactive API documentation |
| http://localhost:8003/api/health | `{"status":"ok","mock_llm":true}` |

---

## Step 2 — First Run

1. Open **http://localhost:5173**

2. **Upload Screen:** Drag-drop PDF files from `data/samples/Patient_003/`  
   (or use your own patient PDFs)

3. Click **"Analyse Documents"**

4. **Processing Screen:** Watch the agent work through each step live  
   — typically 5–10 seconds for typed PDFs

5. **Review Screen:** You will see:
   - 🟢 Found fields with source citations and confidence scores
   - 🟡 Amber cards for missing information  
   - 🔴 Red conflict cards showing competing values from different documents
   - Summary panel: documents analysed, conflicts, drug interactions, completeness %

6. Click **"Review Flags"** tab — resolve conflicts by typing the correct value

7. Click **"Agent Trace"** tab — see every reasoning step the agent took

8. Click **"Run Learning Loop"** — see 3-iteration reward improvement

9. Click **"Export PDF"** — print or save as PDF

---

## Step 3 — Using Real Patient PDFs

1. Go to http://localhost:5173
2. Drop your PDF files in the upload area
3. The system handles:
   - **Multiple files** (6 separate PDFs per patient = standard workflow)
   - **Single combined file** (e.g. a 71-page hospital record — automatically split into sections)
   - **Scanned/image PDFs** (OCR runs automatically — allow ~5 min per 70 pages)

> **Only PDF format is supported.** DOCX and images are not yet supported.

---

## Switching to a Real LLM

After getting an API key, update `.env` and restart:

```bash
# Edit .env:
MOCK_LLM=false
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...

# Docker:
docker compose restart backend

# Manual:
# Stop uvicorn (Ctrl+C), then restart
PYTHONPATH=. .venv/bin/uvicorn backend.main:app --host 0.0.0.0 --port 8003
```

With a real LLM:
- The hospital course narrative is properly synthesised from all document text
- Field extraction is more accurate on unusual document formats
- Conflict resolution suggestions are more intelligent

---

## Troubleshooting

### Port already in use

```bash
# Find what process is using the port
lsof -i :8003        # Mac/Linux
netstat -aon | findstr 8003   # Windows

# Kill it (Mac/Linux):
kill -9 <PID>
```

Or change the port in `.env`:
```env
BACKEND_PORT=8004
```

And update `frontend/vite.config.ts`:
```typescript
proxy: { '/api': 'http://localhost:8004' }
```

### "Module not found" errors

```bash
# Virtual environment not activated
source .venv/bin/activate   # Mac/Linux

# Packages not installed
pip install -r backend/requirements.txt
```

### "Draft not available" after reload

The backend uses in-memory session storage. If the backend restarted, sessions are lost.  
Just upload and process again — it takes seconds for text PDFs.

### Frontend shows blank/old content

```bash
# Hard refresh browser
Ctrl+Shift+R   # Windows/Linux
Cmd+Shift+R    # Mac
```

### OCR produces garbled text

- Low-resolution scanned documents produce noisy OCR — this is expected
- The agent handles noise by flagging uncertain fields for clinician review
- With a real LLM, extraction accuracy improves significantly on noisy text

### Docker: "Cannot connect to Docker daemon"

Make sure Docker Desktop is open and running before running `docker compose`.

---

## Project Structure

```
discharge-agent/
├── backend/          Python FastAPI — agent, tools, OCR, API
├── frontend/         React/Vite — upload, trace, review UI
├── data/
│   ├── samples/      Synthetic patient PDFs for testing
│   ├── uploads/      Runtime: uploaded files (auto-created)
│   └── outputs/      Runtime: trace JSON files (auto-created)
├── Dockerfile.backend
├── Dockerfile.frontend
├── docker-compose.yml
├── .env.example      Copy → .env and configure
├── .env              Your settings (never commit to Git)
└── start.sh          One command: starts backend + frontend
```

---

## Quick Reference

| Task | Docker | Manual |
|---|---|---|
| Start everything | `docker compose up` | `./start.sh` |
| Stop everything | `docker compose down` | `Ctrl+C` |
| Rebuild after changes | `docker compose up --build` | restart servers |
| Generate test PDFs | `docker compose exec backend python3 data/samples/generate_patient3.py` | `python3 data/samples/generate_patient3.py` |
| View API docs | http://localhost:8003/docs | http://localhost:8003/docs |
| Health check | `curl http://localhost:8003/api/health` | same |

---

## Deployment to Production

### Environment

1. Set a real LLM provider in `.env`
2. Replace in-memory sessions with Redis (edit `backend/api/routes.py`)
3. Fill deployment variables:
   ```env
   DATABASE_URL=postgresql://user:pass@host:5432/db
   REDIS_URL=redis://host:6379
   SENTRY_DSN=your_dsn_here
   ```

### Build

```bash
# Build frontend static files
cd frontend && npm run build
# Output: frontend/dist/

# Run backend in production mode (no --reload, multiple workers)
PYTHONPATH=. uvicorn backend.main:app --host 0.0.0.0 --port 8003 --workers 4
```

### Docker Production

```bash
docker compose -f docker-compose.prod.yml up -d
```

Serve `frontend/dist/` via Nginx. Use a reverse proxy (Nginx, Caddy) to route:
- `/api/*` → backend:8003
- `/*` → frontend static files

---

*For questions or issues, check the terminal output first — most problems show a clear error message.*
