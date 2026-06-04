# DischargePilot — Technical Documentation

> Complete architecture reference, component design, API routes, data models, and system flows.

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Directory Structure](#2-directory-structure)
3. [Backend Components](#3-backend-components)
4. [Agent Loop — The Core](#4-agent-loop--the-core)
5. [Tool System](#5-tool-system)
6. [PDF Ingestion Pipeline](#6-pdf-ingestion-pipeline)
7. [Data Models](#7-data-models)
8. [API Routes](#8-api-routes)
9. [LLM Client — Mock/Real Switching](#9-llm-client--mockreal-switching)
10. [Frontend Architecture](#10-frontend-architecture)
11. [Learning Loop (Part 2)](#11-learning-loop-part-2)
12. [Observability and Tracing](#12-observability-and-tracing)
13. [Safety Validation Layer](#13-safety-validation-layer)
14. [Configuration Reference](#14-configuration-reference)
15. [End-to-End Flow](#15-end-to-end-flow)

---

## 1. System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         DISCHARGEPILOT                              │
│                                                                     │
│  ┌──────────────┐   HTTP/JSON    ┌───────────────────────────────┐  │
│  │              │ ◄────────────► │      FastAPI Backend           │  │
│  │   React UI   │                │          :8003                 │  │
│  │  (Vite/TS)   │                │                               │  │
│  │    :5173     │                │  ┌─────────────────────────┐  │  │
│  │              │                │  │    PDF Ingestion         │  │  │
│  │  3 Screens:  │                │  │  pdfplumber → PyMuPDF    │  │  │
│  │  - Upload    │                │  │  → EasyOCR (scanned)     │  │  │
│  │  - Trace     │                │  └────────────┬────────────┘  │  │
│  │  - Review    │                │               │               │  │
│  │              │                │               ▼               │  │
│  └──────────────┘                │  ┌─────────────────────────┐  │  │
│                                  │  │   Working Memory         │  │  │
│                                  │  │   PatientKnowledgeBase   │  │  │
│                                  │  │   FOUND/MISSING/CONFLICT │  │  │
│                                  │  └────────────┬────────────┘  │  │
│                                  │               │               │  │
│                                  │               ▼               │  │
│                                  │  ┌─────────────────────────┐  │  │
│                                  │  │    Agent Loop            │  │  │
│                                  │  │  observe→plan→execute    │  │  │
│                                  │  │  →update→replan (×25)    │  │  │
│                                  │  └────────────┬────────────┘  │  │
│                                  │               │               │  │
│                                  │    ┌──────────┼──────────┐    │  │
│                                  │    ▼          ▼          ▼    │  │
│                                  │  search    reconcile  check_  │  │
│                                  │  _docs     _meds      drug_   │  │
│                                  │  (tool 1)  (tool 2)   inter   │  │
│                                  │                       (tool3) │  │
│                                  │    ┌──────────┬──────────┐    │  │
│                                  │    ▼          ▼          ▼    │  │
│                                  │  flag_for  validate   LLM     │  │
│                                  │  clinician  _field   Client   │  │
│                                  │  (tool 4)  (tool 5)  (mock/   │  │
│                                  │                      real)    │  │
│                                  │               │               │  │
│                                  │               ▼               │  │
│                                  │  ┌─────────────────────────┐  │  │
│                                  │  │  Safety Validator        │  │  │
│                                  │  │  Draft Generator         │  │  │
│                                  │  │  Agent Tracer            │  │  │
│                                  │  └─────────────────────────┘  │  │
│                                  └───────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘

External dependencies:
  - EasyOCR / Tesseract OCR     (for scanned/image PDFs)
  - Anthropic API (optional)    (ANTHROPIC_API_KEY in .env)
  - OpenAI API (optional)       (OPENAI_API_KEY in .env)
  - MOCK_LLM=true               (default — runs fully offline)
```

---

## 2. Directory Structure

```
discharge-agent/
│
├── backend/                        # Python/FastAPI server
│   ├── main.py                     # FastAPI app entry point, CORS config
│   ├── config.py                   # Pydantic settings, reads .env
│   │
│   ├── ingestion/
│   │   └── pdf_parser.py           # PDF parsing: pdfplumber → PyMuPDF → OCR
│   │                               # Includes: doc-type detection, dedup,
│   │                               # OCR pipeline, multi-section splitting
│   │
│   ├── memory/
│   │   └── working_memory.py       # In-memory patient knowledge base
│   │                               # set_field / mark_missing / mark_conflict
│   │                               # add_flag / task_queue management
│   │
│   ├── models/
│   │   └── patient.py              # Pydantic models:
│   │                               # PatientKnowledgeBase, SourcedValue,
│   │                               # Medication, MedicationChange,
│   │                               # DrugInteraction, ClinicalFlag
│   │
│   ├── agent/
│   │   ├── agent_loop.py           # DischargeAgent class — the core agent
│   │   │                           # observe/plan/execute/update/replan loop
│   │   │                           # Task dispatch for all 15 task types
│   │   ├── llm_client.py           # LLMClient — mock or real (Anthropic/OpenAI)
│   │   │                           # Field extraction regex patterns
│   │   │                           # Conflict detection via normalisation
│   │   ├── draft_generator.py      # Converts knowledge base → 13-section draft
│   │   └── learning_loop.py        # Part 2: simulated doctor + reward function
│   │
│   ├── tools/
│   │   ├── search_tool.py          # Keyword search across all document pages
│   │   ├── medication_tool.py      # Medication reconciliation (add/remove/change)
│   │   ├── drug_interaction_tool.py # Clinical interaction database check
│   │   └── escalation_tool.py      # flag_for_clinician / resolve_flag
│   │
│   ├── validator/
│   │   └── safety_validator.py     # Source-evidence check, interaction warnings
│   │
│   ├── tracer/
│   │   └── agent_tracer.py         # Per-step JSON trace, saved to data/outputs/
│   │
│   └── api/
│       └── routes.py               # All FastAPI endpoints (see Section 8)
│
├── frontend/                       # React + Vite + TypeScript + Tailwind
│   ├── src/
│   │   ├── App.tsx                 # Route state machine (upload→processing→review)
│   │   │                           # URL param: ?session=ID&state=review
│   │   ├── pages/
│   │   │   ├── UploadPage.tsx      # Drag-drop PDF upload
│   │   │   ├── ProcessingPage.tsx  # Live agent trace timeline
│   │   │   └── ReviewPage.tsx      # 4-tab review (draft/flags/trace/learning)
│   │   ├── components/
│   │   │   ├── FieldValue.tsx      # Renders FOUND/MISSING/CONFLICT field
│   │   │   └── SectionCard.tsx     # Titled card with status icon
│   │   ├── lib/
│   │   │   └── api.ts              # Axios API calls to /api/*
│   │   └── types/
│   │       └── index.ts            # TypeScript type definitions
│   ├── vite.config.ts              # Vite config — proxy /api → :8003
│   └── index.html                  # App shell, Inter font link
│
├── data/
│   ├── samples/
│   │   ├── Patient_001/            # Synthetic patient — NSTEMI
│   │   ├── Patient_002/            # Company-provided scanned PDF (71 pages)
│   │   ├── Patient_003/            # Synthetic patient — HFrEF + AF
│   │   ├── generate_samples.py     # Generates Patient_001 PDFs
│   │   └── generate_patient3.py    # Generates Patient_003 PDFs
│   ├── uploads/                    # Runtime: uploaded files (per session UUID)
│   └── outputs/                    # Runtime: trace JSON files
│
├── .env                            # Local environment (git-ignored)
├── .env.example                    # Template — all variables documented
├── start.sh                        # Single command to start backend + frontend
├── PROJECT_OVERVIEW.txt            # Plain English explanation
├── TECHNICAL_DOCS.md               # This file
└── SETUP_GUIDE.md                  # Setup and run instructions
```

---

## 3. Backend Components

### 3.1 FastAPI Application (`backend/main.py`)

```python
app = FastAPI(title="Discharge Summary Agent API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins_list)
app.include_router(router, prefix="/api")
```

- All API endpoints are prefixed with `/api`
- CORS is configured via `CORS_ORIGINS` env var (default: `localhost:3000,localhost:5173`)
- Interactive API docs: `http://localhost:8003/docs`

### 3.2 Settings (`backend/config.py`)

Uses Pydantic `BaseSettings` — reads from environment and `.env` file:

| Variable | Default | Purpose |
|---|---|---|
| `MOCK_LLM` | `true` | Use mock responses (no API key needed) |
| `LLM_PROVIDER` | `mock` | `mock` / `anthropic` / `openai` |
| `ANTHROPIC_API_KEY` | `""` | API key for Claude models |
| `ANTHROPIC_MODEL` | `claude-sonnet-4-6` | Claude model to use |
| `OPENAI_API_KEY` | `""` | API key for GPT models |
| `AGENT_MAX_STEPS` | `25` | Maximum agent loop iterations |
| `BACKEND_PORT` | `8003` | Server port |

### 3.3 Session Management

Sessions are currently stored **in-memory** (Python dict) per backend process:

```python
sessions: dict[str, dict] = {}
# key: session_id (UUID)
# value: { status, files, upload_dir, result, draft, trace, flags }
```

> **Production note:** For multi-instance deployment, replace with Redis or a database.
> Processing runs as a FastAPI BackgroundTask.

---

## 4. Agent Loop — The Core

The `DischargeAgent` class in `backend/agent/agent_loop.py` implements the full
observe → plan → execute → update → replan cycle.

### 4.0 Agent State Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     DISCHARGEPILOT AGENT                    │
│                                                             │
│   ┌─────────────┐                                           │
│   │   OBSERVE   │  ← Read working memory state             │
│   │             │    (what fields are FOUND / MISSING)      │
│   └──────┬──────┘                                           │
│          │                                                  │
│          ▼                                                  │
│   ┌─────────────┐                                           │
│   │    PLAN     │  ← Select next task from queue           │
│   │             │    (15 structured tasks in order)         │
│   └──────┬──────┘                                           │
│          │                                                  │
│          ▼                                                  │
│   ┌─────────────┐                                           │
│   │  EXECUTE    │  ← Call the appropriate tool:            │
│   │    TOOL     │    search_documents / reconcile_meds /    │
│   │             │    check_interactions / flag_clinician /  │
│   │             │    validate_field                         │
│   └──────┬──────┘                                           │
│          │                                                  │
│          ▼                                                  │
│   ┌─────────────┐                                           │
│   │   UPDATE    │  ← Write result to PatientKnowledgeBase  │
│   │   MEMORY    │    Status: FOUND / MISSING / CONFLICT     │
│   └──────┬──────┘                                           │
│          │                                                  │
│          ▼                                                  │
│   ┌─────────────┐                                           │
│   │  VALIDATE   │  ← Every FOUND field must cite a source  │
│   │             │    No source = field rejected (no guess)  │
│   └──────┬──────┘                                           │
│          │                                                  │
│     more tasks?                                             │
│     ├─ YES → back to OBSERVE (next task)                   │
│     └─ NO  ──▼                                             │
│                                                             │
│   ┌─────────────┐                                           │
│   │   REPLAN    │  ← Second pass for still-missing fields  │
│   │             │    Broader search strategy applied        │
│   └──────┬──────┘                                           │
│          │                                                  │
│          ▼                                                  │
│   ┌─────────────┐                                           │
│   │  COMPLETE   │  ← Generate structured 13-section draft  │
│   │             │    Outcome: complete / partial /          │
│   │             │    max_steps_reached                      │
│   └─────────────┘                                           │
│                                                             │
│   Every step is logged to AgentTracer → JSON trace file    │
└─────────────────────────────────────────────────────────────┘
```

**Key safety invariant**: The agent never invents information. If no supporting
evidence is found in the source documents, the field is marked MISSING and
flagged for clinician review — not filled with a guess.

### 4.1 Loop Diagram

```
                    ┌─────────────────────────────┐
                    │    DischargeAgent.run()      │
                    └──────────────┬──────────────┘
                                   │
                    ┌──────────────▼──────────────┐
                    │   _initial_plan()            │
                    │   Build task queue (15 tasks)│
                    └──────────────┬──────────────┘
                                   │
              ┌────────────────────▼────────────────────┐
              │         MAIN AGENT LOOP                  │
              │   while step < MAX_STEPS                 │
              │         and task_queue not empty:        │
              │                                          │
              │  ┌─────────────────────────────────┐    │
              │  │  observe() — read memory state   │    │
              │  └──────────────┬──────────────────┘    │
              │                 │                        │
              │  ┌──────────────▼──────────────────┐    │
              │  │  _execute_task(task)             │    │
              │  │  → one of 15 task handlers       │    │
              │  └──────────────┬──────────────────┘    │
              │                 │                        │
              │  ┌──────────────▼──────────────────┐    │
              │  │  update memory + tracer          │    │
              │  └──────────────┬──────────────────┘    │
              │                 │                        │
              │  ┌──────────────▼──────────────────┐    │
              │  │  complete_task(task)             │    │
              │  └──────────────┬──────────────────┘    │
              │                 │ next task               │
              └─────────────────┴────────────────────────┘
                                │
              ┌─────────────────▼────────────────────────┐
              │  REPLANNING PASS                          │
              │  Check get_missing_fields()               │
              │  For each scalar field still missing:     │
              │    → retry _extract_scalar_field(f)       │
              └─────────────────┬────────────────────────┘
                                │
              ┌─────────────────▼────────────────────────┐
              │  FINALIZE                                 │
              │  outcome: complete / partial /            │
              │           max_steps_reached               │
              │  tracer.finalize()                        │
              │  return result dict                       │
              └──────────────────────────────────────────┘
```

### 4.2 Task Queue (15 tasks in order)

| # | Task | What it does |
|---|---|---|
| 1 | `extract_demographics` | patient_name, dob, mrn, gender |
| 2 | `extract_admission_info` | admission_date, attending, ward |
| 3 | `extract_discharge_info` | discharge_date |
| 4 | `extract_diagnoses` | principal + secondary diagnoses |
| 5 | `extract_allergies` | allergy list |
| 6 | `extract_admission_medications` | home meds on admission |
| 7 | `extract_discharge_medications` | discharge med list |
| 8 | `reconcile_medications` | compute added/removed/changed |
| 9 | `check_interactions` | drug interaction check |
| 10 | `extract_procedures` | procedures / interventions |
| 11 | `extract_followup` | follow-up instructions |
| 12 | `check_pending` | pending lab / imaging results |
| 13 | `extract_hospital_course` | synthesise narrative |
| 14 | `extract_discharge_condition` | discharge condition |
| 15 | `safety_validate` | run safety validator |

### 4.3 Conflict Detection

```
For each scalar field F:
  1. Search all documents for F with field-specific queries
  2. Group results by document type (prevents same-doc false conflicts)
  3. Extract one value per document type via LLM client
  4. Normalise values: remove punctuation, lowercase
  5. If normalised values differ → CONFLICT
     → mark_conflict(F, all_values_with_sources)
     → flag_for_clinician(issue_type="conflict")
  6. Else → use highest-confidence value
```

Conflict-prone fields (where cross-doc check is always run):
- `principal_diagnosis`
- `attending_physician`
- `discharge_condition`

---

## 5. Tool System

Five tools the agent can call:

### Tool 1 — `search_documents(query, documents, top_k=5)`

```
Location: backend/tools/search_tool.py

Input:  query string, list of parsed documents
Output: list[SearchResult] sorted by relevance

Algorithm:
  - Tokenise query into terms
  - For each document page, count query term hits
  - Score = matched_terms / total_terms
  - Return top-K pages by score with excerpt around first match
```

### Tool 2 — `reconcile_medications(admission_meds, discharge_meds)`

```
Location: backend/tools/medication_tool.py

Input:  two lists of Medication objects
Output: list[MedicationChange]

Algorithm:
  - Build maps: {normalised_name → Medication}
  - For each unique medication name:
    - In admission only → "removed"
    - In discharge only → "added"
    - In both, different dose/route → "changed"
```

### Tool 3 — `check_drug_interactions(medications)`

```
Location: backend/tools/drug_interaction_tool.py

Input:  list of medication name strings
Output: list[DrugInteraction]

Algorithm:
  - Normalise each medication name
  - For each pair in clinical interaction DB:
    - Check if both drugs appear in the medication list
    - Deduplicate A+B and B+A pairs
  - Return all matched interactions with severity + description

Severity levels: HIGH / MEDIUM / LOW
```

### Tool 4 — `flag_for_clinician(memory, issue_type, description, context)`

```
Location: backend/tools/escalation_tool.py

Creates a ClinicalFlag record in working memory with:
  - Unique flag_id (UUID fragment)
  - issue_type: conflict | missing_data | drug_interaction | agent_error
  - description + context
  - resolved: False (doctor resolves via UI)
  
Deduplication: if same issue_type + description exists, returns existing flag_id
```

### Tool 5 — `validate_field(memory)` (via safety_validator)

```
Location: backend/validator/safety_validator.py

Checks:
  - Every FOUND field has source_file + page
  - No FOUND field without evidence (hallucination guardrail)
  - All discharge medications have source evidence
  - HIGH interactions flagged
  - Allergy documented (or flagged if missing)
```

---

## 6. PDF Ingestion Pipeline

```
parse_pdf(file_path)
     │
     ├── _is_image_based()?
     │       ├── YES → parse_with_ocr()
     │       │           ├── For each page:
     │       │           │     extract embedded images
     │       │           │     → _ocr_page_image(image_bytes)
     │       │           │           → EasyOCR (primary)
     │       │           │           → Tesseract subprocess (fallback)
     │       │           └── split_combined_pdf_by_ocr()
     │       │                   ├── _identify_primary_patient()
     │       │                   │     → find most frequent patient ID
     │       │                   ├── Filter pages by patient ID
     │       │                   └── Split by SECTION_MARKERS into logical docs
     │       │
     │       └── NO → parse_with_pdfplumber()
     │                   → fallback: parse_with_pymupdf()
     │
     └── detect_doc_type(full_text)
             → keyword scoring across 5 document types:
               admission / progress / labs / medications / discharge
```

### Section Markers (used for multi-section PDF splitting)

| Section type | Marker keywords |
|---|---|
| `discharge` | DISCHARGE SUMMARY, DISCHARGE AT REQUEST, DISCHARGE DIAGNOSIS |
| `admission` | ADMISSION NOTE, HISTORY OF PRESENT, CHIEF COMPLAINT |
| `progress` | PROGRESS NOTE, NURSES NOTES, NURSING NOTES |
| `labs` | INVESTIGATIONS, LABORATORY, CBC:, HAEMATOLOGY |
| `medications` | MEDICATION ORDER, DRUG ORDER, DISCHARGE MEDICATIONS |
| `radiology` | RADIOLOGY, X-RAY, CT SCAN, USG, ECHO, IMPRESSION |
| `nursing` | NURSING ASSESSMENT, BED SORES, INTAKE/OUTPUT |
| `consultation` | CONSULTATION SHEET, CONSULTANT: |

---

## 7. Data Models

### SourcedValue (the fundamental unit)

```python
class SourcedValue(BaseModel):
    value: Optional[str] = None          # The extracted text
    source_file: Optional[str] = None    # Which document it came from
    page: Optional[int] = None           # Which page
    confidence: float = 0.0             # 0.0–1.0
    status: FieldStatus = MISSING        # FOUND | MISSING | CONFLICT | PENDING
    conflict_values: list[dict] = []    # All competing values with sources
    clinician_review_required: bool = False
    clinician_note: Optional[str] = None
```

### PatientKnowledgeBase

```python
class PatientKnowledgeBase(BaseModel):
    session_id: str

    # Demographics (SourcedValue each)
    patient_name, dob, mrn, gender

    # Dates & clinical context (SourcedValue each)
    admission_date, discharge_date, attending_physician, ward

    # Diagnoses
    principal_diagnosis: SourcedValue
    secondary_diagnoses: list[SourcedValue]

    # Safety-critical
    allergies: list[SourcedValue]

    # Medications
    admission_medications: list[Medication]
    discharge_medications: list[Medication]
    medication_changes: list[MedicationChange]
    drug_interactions: list[DrugInteraction]

    # Clinical
    procedures: list[SourcedValue]
    hospital_course: SourcedValue
    pending_results: list[SourcedValue]
    follow_up_instructions: list[SourcedValue]
    discharge_condition: SourcedValue

    # Agent state
    clinical_flags: list[ClinicalFlag]
    documents: list[dict]  # parsed document metadata
```

### Field Status Enum

```
FOUND   → Value extracted, source cited, confidence ≥ threshold
MISSING → Not found in any document → amber in UI, clinician review
CONFLICT→ Different values found in different documents → red in UI
PENDING → Found but explicitly marked as pending in document
```

---

## 8. API Routes

Base URL: `http://localhost:8003/api`
Interactive docs: `http://localhost:8003/docs`

| Method | Route | Purpose | Request | Response |
|---|---|---|---|---|
| `GET` | `/health` | Health check | — | `{status, mock_llm, llm_provider}` |
| `POST` | `/upload` | Upload PDFs | `multipart/form-data files=[]` | `{session_id, files_received}` |
| `POST` | `/process/{session_id}` | Start agent | — | `{session_id, status}` |
| `GET` | `/status/{session_id}` | Poll status | — | `{status, error}` |
| `GET` | `/draft/{session_id}` | Get draft | — | Full draft JSON |
| `GET` | `/trace/{session_id}` | Get trace | — | Full trace JSON |
| `GET` | `/flags/{session_id}` | Get flags | — | `{flags: [ClinicalFlag]}` |
| `POST` | `/flags/{session_id}/{flag_id}/resolve` | Resolve flag | `?resolution=text` | `{status}` |
| `POST` | `/draft/{session_id}/field` | Update field | `{section, field, value}` | `{status}` |
| `POST` | `/learning/{session_id}` | Run learning loop | — | `{learning_results}` |

### Draft Response Structure

```json
{
  "generated_at": "2025-06-04T00:00:00",
  "session_id": "abc123",
  "completeness_score": 77.8,
  "sections": {
    "patient_demographics": {
      "patient_name": {"value": "Maria Elena Fernandez", "status": "found",
                       "source": "01_admission_note.pdf p.1", "confidence": 0.9},
      "date_of_birth": {"value": "11/07/1966", "status": "found", ...},
      ...
    },
    "admission_date": {"value": "March 14, 2025", "status": "found", ...},
    "discharge_date": {"value": null, "status": "missing",
                       "clinician_note": "Discharge Date not found. Review required."},
    "principal_diagnosis": {
      "value": null,
      "status": "conflict",
      "conflict_values": [
        {"value": "Acute decompensated HF", "source_file": "01_admission...", "page": 1},
        {"value": "HFrEF", "source_file": "06_discharge...", "page": 1}
      ]
    },
    ...
  },
  "clinical_flags": [
    {"flag_id": "a1b2c3d4", "issue_type": "conflict",
     "description": "Conflicting values for 'principal_diagnosis'",
     "resolved": false}
  ]
}
```

### Trace Response Structure

```json
{
  "session_id": "abc123",
  "start_time": "2025-06-04T00:00:00",
  "end_time": "2025-06-04T00:00:05",
  "total_steps": 19,
  "outcome": "partial",
  "unresolved_items": ["discharge_date"],
  "steps": [
    {
      "step": 0, "action": "initialize",
      "reasoning": "Ingested 6 documents. Building task queue with 15 tasks.",
      "result": {"tasks": [...]},
      "duration_ms": 0.01, "status": "success"
    },
    {
      "step": 1, "action": "extract_demographics",
      "reasoning": "Extracting patient demographics. Found: [name, dob, mrn, gender]",
      "result": {"patient_name": "found", ...},
      "duration_ms": 1.3, "status": "success"
    },
    ...
  ]
}
```

---

## 9. LLM Client — Mock/Real Switching

`backend/agent/llm_client.py` provides a unified interface:

```
LLMClient
  ├── provider = "mock"       → intelligent regex extraction, no API call
  ├── provider = "anthropic"  → Anthropic Claude API
  └── provider = "openai"     → OpenAI API

Methods:
  .plan(missing_fields, completed_tasks) → next action dict
  .extract_field(field, search_results, all_documents) → extracted value
  .detect_conflicts(field, values) → conflict decision
  .generate_hospital_course(documents) → narrative string
  .generate_allergies_from_text(documents) → list of allergy strings
```

### Mock Mode (MOCK_LLM=true)

In mock mode, extraction uses direct regex over the full document text:

```python
FIELD_PATTERNS = {
    "patient_name": [
        r"Patient Name[^\n]*?(?:Mr\.?|Mrs\.?|Ms\.?)[\.:\s]+([A-Z][\w\s\.]+?)...",
        r"Patient Name[^\n]{0,10}?([A-Z](?:\s+[A-Z]){1,3}\s+[A-Z][a-z]+)",
        ...
    ],
    "admission_date": [
        r"DOA[:\s]+([\d]{1,2}[-/\.][\d]{1,2}[-/\.][\d]{2,4})",
        ...
    ],
    ...
}
```

Documents are searched in priority order:
`discharge(0) → medications(1) → admission(2) → progress(3) → labs(4) → other(9)`

### Switching to Real LLM

```bash
# In .env:
MOCK_LLM=false
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_MODEL=claude-sonnet-4-6
```

No code changes required. The LLMClient detects the provider and uses
structured JSON prompts with strict hallucination guardrails in the system prompt.

---

## 10. Frontend Architecture

### State Machine (App.tsx)

```
'upload' ──► 'processing' ──► 'review'
   │                              │
   │              ┌───────────────┘
   │              ▼
   └──────────── 'error'

URL params: ?session=<id>&state=review  (jump directly to review for demo)
```

### Page Components

```
UploadPage
  - File drag-drop (DnD events)
  - PDF-only filter
  - Doc-type badge (guessDocType from filename)
  - Calls: uploadDocuments() → processSession()
  - On success: onSessionStarted(session_id)

ProcessingPage
  - Polls /status every 1.5s
  - Polls /trace every 2s for live step display
  - StepRow: expandable with reasoning + next_decision
  - On complete: onComplete() → ReviewPage

ReviewPage (4 tabs)
  ├── "Discharge Summary" tab
  │     Left column (2/3 width):
  │       SectionCard: Patient Demographics
  │       SectionCard: Encounter Details
  │       SectionCard: Diagnoses (with conflict card)
  │       SectionCard: Hospital Course
  │       SectionCard: Discharge Medications
  │       SectionCard: Medication Changes (ADDED/REMOVED/CHANGED badges)
  │       SectionCard: Drug Interactions (severity badges)
  │       SectionCard: Follow-up Instructions
  │       SectionCard: Pending Results
  │     Right column (1/3 width):
  │       SectionCard: Discharge Condition
  │       SectionCard: Allergies
  │       SectionCard: Procedures
  │       Summary stats box
  │
  ├── "Review Flags" tab
  │     FlagCard per ClinicalFlag
  │     Expandable: shows context
  │     Resolution input + Resolve button
  │
  ├── "Agent Trace" tab
  │     TraceStepRow per AgentStep
  │     Expandable: reasoning + next_decision + errors
  │
  └── "Learning Loop" tab
        Reward bar chart (amplified scale)
        Iteration cards: reward %, corrections applied
```

### Key Components

**FieldValue** renders a SourcedField based on its status:
```
status=found    → green text + source citation + hover edit button
status=missing  → amber box: "Not documented — clinician review required"
status=conflict → red box: list of competing values with source badges
status=pending  → clock icon + value
```

**SectionCard** wraps each section with:
```
status=ok      → green check icon, white border
status=warning → amber triangle icon, amber border
status=error   → red X icon, red border
```

---

## 11. Learning Loop (Part 2)

`backend/agent/learning_loop.py`

### Architecture

```
Iteration 1:
  Agent.run(documents) → draft
  simulate_doctor_review(draft) → corrected_draft + corrections + reward₁
  Store corrections in correction_memory

Iteration 2:
  Agent.run(documents, correction_memory injected)
  apply_learned_corrections(draft, learned_rule_ids)  ← pre-applies corrections
  simulate_doctor_review(corrected_draft) → reward₂

Iteration 3:
  Same as 2 with accumulated memory → reward₃ ≥ reward₂ ≥ reward₁
```

### Reward Function

```python
reward = 1.0 - normalized_edit_distance(original_text, corrected_text)

normalized_edit_distance = levenshtein_distance(a, b) / max(len(a), len(b))

# reward = 1.0 → no edits needed → perfect
# reward = 0.96 → 4% of characters required correction
```

### Simulated Doctor Rules

| Rule ID | What it checks | Fix applied |
|---|---|---|
| `attending_signature_required` | Attending physician field is CONFLICT/MISSING | Adds placeholder signature line |
| `pending_labs_explicit` | Pending results section is empty | Adds "No pending results at discharge" |
| `allergy_nkda_explicit` | Allergy status is MISSING | Adds "Allergy not verified — confirm with patient" |
| `hospital_course_length` | Hospital course < 100 chars | Appends "Clinician note: expand narrative" |
| `drug_interactions_acknowledged` | HIGH severity interaction present | Appends acknowledgement note |

---

## 12. Observability and Tracing

Every agent step is recorded with:

```python
@dataclass
class AgentStep:
    step: int          # step number (0 = initialize)
    timestamp: str     # ISO 8601 UTC
    reasoning: str     # why the agent took this action
    action: str        # what action was taken
    input: Any         # what was passed to the action
    result: Any        # what came back
    memory_update: dict # what changed in working memory
    next_decision: str  # what the agent will do next
    duration_ms: float  # how long it took
    status: str         # "success" | "error"
    error: Optional[str]
```

Traces are saved to `data/outputs/trace_{session_id}.json` after each run.

---

## 13. Safety Validation Layer

`backend/validator/safety_validator.py`

Runs after the main agent loop, before draft generation.

**Checks:**

1. **Source evidence** — every FOUND field must have `source_file` + `page`
   → If missing: `reject_field(field, "No source evidence — potential hallucination")`

2. **Discharge medication evidence** — every medication must cite source
   → If missing: `add_error("Medication '{name}' has no source evidence")`

3. **High-severity interactions** — already caught but re-validated
   → `add_warning("HIGH drug interaction: A + B")`

4. **Allergy documentation** — if empty list:
   → `add_warning("No allergy information found — clinician review required")`

---

## 14. Configuration Reference

All configuration is in `.env`:

```bash
# LLM (pick one or leave MOCK_LLM=true for testing)
MOCK_LLM=true
LLM_PROVIDER=mock              # mock | anthropic | openai
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-sonnet-4-6
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4.1

# Agent
AGENT_MAX_STEPS=25             # max loop iterations (increase for complex records)
AGENT_CONFIDENCE_THRESHOLD=0.7

# Server
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8003
CORS_ORIGINS=http://localhost:3000,http://localhost:5173

# Storage
DATA_DIR=./data
OUTPUTS_DIR=./data/outputs
UPLOADS_DIR=./data/uploads
```

---

## 15. End-to-End Flow

```
User uploads PDFs
        │
        ▼
POST /api/upload
  → Files saved to data/uploads/{session_id}/
  → session created: { status: "uploaded" }
        │
        ▼
POST /api/process/{session_id}
  → Background task started
  → session status → "processing"
        │
        ▼
parse_patient_folder(upload_dir)
  → For each PDF:
      is_image_based? → OCR pipeline
      else → pdfplumber / PyMuPDF
  → Returns list[ParsedDocument] with full_text + doc_type
        │
        ▼
DischargeAgent(session_id).run(documents)
  → add_document() for each doc → WorkingMemory
  → _initial_plan() → 15-task queue
  → Main loop (≤25 steps):
      Each task → _execute_task()
        → calls search/extraction/reconciliation tools
        → updates PatientKnowledgeBase
        → logs to AgentTracer
  → Replan pass for remaining missing scalar fields
  → tracer.finalize(outcome)
        │
        ▼
generate_draft(PatientKnowledgeBase)
  → 13-section structured dict
  → completeness_score computed
        │
        ▼
session updated: { status: "complete", draft, trace, flags }
        │
        ▼
Frontend polls GET /api/status → "complete"
  → GET /api/draft → renders ReviewPage
  → GET /api/trace → renders Agent Trace tab
  → GET /api/flags → renders Review Flags tab
        │
        ▼
Doctor resolves flags, fills missing fields
  → POST /api/flags/{id}/resolve
  → POST /api/draft/{id}/field
        │
        ▼
(Optional) POST /api/learning → 3-iteration learning loop
  → Returns reward progression: 96.1% → 100% → 100%
```

---

*DischargePilot — Built as an Agentic AI System Design challenge.*
*Demonstrates: custom agent loops, planning/replanning, tool calling,*
*conflict detection, safety guardrails, observability, and HITL workflows.*
