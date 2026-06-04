# DischargePilot

**Agentic AI system for clinically safe hospital discharge summary generation.**

---

## The Problem

Traditional AI summary tools pipe documents directly into an LLM:

```
PDFs → LLM → Summary
```

This is clinically dangerous. The LLM can hallucinate — inventing drug doses, allergies, or diagnoses that were never in the source documents. A single fabricated value can harm a patient.

**DischargePilot takes a fundamentally different approach.**

---

## Architecture

```
PDFs
  │
  ▼
OCR / Extraction
  (pdfplumber → PyMuPDF → EasyOCR for scanned/handwritten pages)
  │
  ▼
Agent Planner  ←─────────────────────────────────────────┐
  │                                                       │
  ▼                                                       │
Tool Calls (×15 structured tasks)                        │
  ├── search_documents        ← keyword search across all pages
  ├── reconcile_medications   ← diff admission vs discharge meds
  ├── check_drug_interactions ← clinical interaction database
  ├── flag_for_clinician      ← surface issues for human review
  └── validate_field          ← every FOUND field must have a source
  │                                                       │
  ▼                                                       │
Conflict Detection                                        │
  (same field, different values in different docs → CONFLICT flag)
  │                                                       │
  ▼                                                       │
Safety Validation                                         │
  (no source evidence → field rejected, not guessed)      │
  │                                                       │
  ▼                                                       │
Still missing fields?  ────── YES ──────────────────────┘
  │ NO
  ▼
Draft Generation
  (13-section structured output — FOUND / MISSING / CONFLICT per field)
  │
  ▼
Clinician Review
  (doctor resolves conflicts, fills missing, exports PDF)
  │
  ▼
Learning Loop  (Part 2)
  (simulated doctor edits → edit-distance reward → agent improves)
```

### Agent State Diagram

```
OBSERVE  →  PLAN  →  EXECUTE TOOL  →  UPDATE MEMORY  →  VALIDATE
                                                              │
                                                         more tasks?
                                                         ├─ YES → OBSERVE
                                                         └─ NO  → REPLAN → COMPLETE
```

---

## Key Safety Properties

| Property | What it prevents |
|---|---|
| **Source-only extraction** | Hallucination — no cited source = field marked MISSING, never guessed |
| **Conflict detection** | Silent errors — when two documents disagree, both values are shown |
| **Drug interaction check** | Missed dangerous combinations before discharge |
| **Safety validation** | Final pass — every FOUND field must cite a real document and page |
| **Clinician-in-the-loop** | Agent surfaces information; doctor makes the clinical decision |

---

## What the Agent Produces Per Field

Every extracted field carries full provenance:

```json
{
  "patient_name": {
    "value": "Maria Elena Fernandez",
    "status": "found",
    "source": "01_admission_note.pdf p.1",
    "confidence": 0.9
  },
  "discharge_date": {
    "value": null,
    "status": "missing",
    "clinician_note": "Discharge Date not found. Review required."
  },
  "principal_diagnosis": {
    "value": null,
    "status": "conflict",
    "conflict_values": [
      {"value": "Acute decompensated HFrEF", "source_file": "01_admission_note.pdf", "page": 1},
      {"value": "HFrEF with AF", "source_file": "06_discharge_summary.pdf", "page": 1}
    ]
  }
}
```

---

## Confidence Score Formula

```
confidence = (
    extraction_pattern_strength  * 0.50   # how specific the regex / LLM prompt match was
  + document_priority_weight     * 0.30   # discharge note > admission note > progress note
  + cross_document_agreement     * 0.20   # same value found in multiple doc types
)
```

Displayed in the UI as a colour-coded bar (green ≥ 85%, amber ≥ 65%, red < 65%) with a percentage alongside the source citation.

---

## Learning Loop (Part 2)

The system includes a 3-iteration learning loop demonstrating how an agent improves from simulated clinician feedback:

```
Iteration 1:  75.5%  — 5 doctor corrections required (attending, drug interactions, GP handover, reconciliation, coding review)
Iteration 2:  82.5%  — agent pre-applies 2 learned rules; 3 corrections still needed
Iteration 3:  89.5%  — agent pre-applies 2 more rules; 2 corrections remain (require human action, cannot be automated)
```

**Note on perfect convergence:** Reaching 100% in 3 iterations is unrealistic in production. Real patients have OCR noise, format variation, and clinical edge cases that require many more iterations to fully capture. The learning loop here demonstrates the *mechanism* of reward-guided improvement — not production-ready convergence.

Reward formula:
```python
reward = 1.0 - levenshtein_distance(original_text, corrected_text) / max(len(original), len(corrected))
```

---

## Demo Walkthrough (Video Guide)

### Scene 1 — Clean Patient (Patient A: Maria Elena Fernandez / Patient 001)

1. Upload all 6 PDFs from `data/samples/Patient_001/`
2. Click **Analyse Documents**
3. Watch the live agent trace timeline
4. Review the structured discharge summary:
   - Green fields with source citations and confidence bars
   - Medication changes (ADDED / REMOVED / CHANGED badges)
   - Drug interactions panel
5. Show **Agent Trace** tab — every reasoning step

### Scene 2 — Conflict Patient (Patient B: Patient 003 — HFrEF + AF)

1. Upload all 6 PDFs from `data/samples/Patient_003/`
2. Click **Analyse Documents**
3. Review the structured summary showing:
   - 🔴 **Conflict** on principal diagnosis (3 competing values with sources)
   - 🟡 **Missing** discharge date — clinician review required
   - ⚠️ **HIGH** drug interaction flag
4. Show **Review Flags** tab — resolve a conflict by typing the clinical decision
5. Show the resolved flag turning green

### Scene 3 — Agent Trace Tab

Point out:
- Step number, action name, reasoning text
- Duration (milliseconds per step)
- "Next Decision" explaining what the agent planned to do next
- Error steps (if any) showing the agent flagged and continued

### Scene 4 — Learning Loop Tab

1. Click **Run Learning Loop**
2. When results appear, show the bar chart:
   - Iteration 1: ~78%
   - Iteration 2: ~82%
   - Iteration 3: ~89%
3. Expand each iteration card to show which corrections were applied

---

## Recording Your Video

**Recommended: QuickTime Player (built-in on Mac, free)**

1. Open QuickTime Player
2. File → New Screen Recording
3. Click the dropdown arrow next to the record button → select your microphone
4. Click the red record button, then click your screen area to begin
5. When done: click the stop button in the menu bar → save

**Suggested script (4 minutes):**
- 0:00–0:30 — Architecture slide / diagram (explain the agent approach vs simple LLM)
- 0:30–1:30 — Upload Patient_001, process, walk through the review screen
- 1:30–3:00 — Upload Patient_003, show conflicts / missing / drug interaction, resolve a flag
- 3:00–3:45 — Agent trace walkthrough (expand 2-3 steps)
- 3:45–4:00 — Run learning loop, show reward chart

---

## Quick Start

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for full instructions.

**One-command start (manual path):**
```bash
cp .env.example .env    # configure LLM provider (MOCK_LLM=true works offline)
./start.sh              # starts backend :8003 + frontend :5173
```

Open http://localhost:5173

---

## Project Structure

```
discharge-agent/
├── backend/
│   ├── agent/          agent_loop.py  llm_client.py  draft_generator.py  learning_loop.py
│   ├── tools/          search  medication  drug_interactions  escalation
│   ├── ingestion/      pdf_parser.py (pdfplumber → PyMuPDF → EasyOCR)
│   ├── memory/         working_memory.py (PatientKnowledgeBase)
│   ├── validator/      safety_validator.py
│   └── api/            routes.py (FastAPI)
├── frontend/
│   └── src/
│       ├── pages/      UploadPage  ProcessingPage  ReviewPage
│       └── components/ FieldValue  SectionCard
├── data/
│   └── samples/        Patient_001/  Patient_003/
├── PROJECT_OVERVIEW.md  ← plain English explanation
├── TECHNICAL_DOCS.md    ← full architecture reference
└── SETUP_GUIDE.md       ← setup and run instructions
```

---

*Built as an Agentic AI System Design challenge demonstrating: custom agent loops, planning & replanning, tool calling, conflict detection, safety guardrails, full observability, and human-in-the-loop workflows.*
