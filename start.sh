#!/bin/bash
# Start both backend and frontend dev servers

ROOT="$(cd "$(dirname "$0")" && pwd)"

# Load .env to pick up BACKEND_PORT (default: 8003)
if [ -f "$ROOT/.env" ]; then
  export $(grep -v '^#' "$ROOT/.env" | grep -v '^$' | xargs)
fi
PORT="${BACKEND_PORT:-8003}"

# Backend
echo "Starting backend on http://localhost:${PORT} ..."
cd "$ROOT"
PYTHONPATH="$ROOT" "$ROOT/.venv/bin/uvicorn" backend.main:app \
  --host 0.0.0.0 --port "${PORT}" --reload &
BACKEND_PID=$!

# Frontend
echo "Starting frontend on http://localhost:5173 ..."
cd "$ROOT/frontend"
npm run dev &
FRONTEND_PID=$!

echo ""
echo "┌──────────────────────────────────────────────┐"
echo "│  Backend  → http://localhost:${PORT}            │"
echo "│  API docs → http://localhost:${PORT}/docs       │"
echo "│  Frontend → http://localhost:5173            │"
echo "└──────────────────────────────────────────────┘"
echo ""
echo "Press Ctrl+C to stop both servers."

trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null" EXIT
wait
