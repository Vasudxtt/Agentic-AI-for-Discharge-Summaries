# DischargePilot — Project Overview

> What it is, what it does, how it works, and why it matters. Written in plain English — no technical background required.

---

## The Problem

When a patient leaves hospital, a doctor must write a **discharge summary** — a document capturing everything that happened: why the patient came in, what was found, what treatments were given, what medicines to take home, what follow-up is needed.

This document is critical. The next GP, specialist, or emergency doctor will rely on it entirely. An incorrect or incomplete discharge summary can directly harm patients.

The challenge:

- A single hospital stay produces **dozens of documents**: admission notes, daily progress notes, lab reports, medication charts, radiology reports, nursing assessments
- These documents often **contradict each other** — one note may say one diagnosis, another a slightly different one
- Some documents are **handwritten and scanned** — a computer cannot even read them without extra work
- Doctors are busy. Writing this manually takes 30–60 minutes and mistakes happen — missing medications, overlooked drug interactions, forgotten pending tests

Most existing "AI summary" tools send all the text to an AI and ask it to write a summary. This is dangerous: the AI **invents** information it did not find (called "hallucination"). A hallucinated drug dose or allergy can hurt patients.

**DischargePilot solves this properly.**

---

## What DischargePilot Does

DischargePilot is an **intelligent agent** — not a simple text summariser.

Think of it as a meticulous medical secretary that:

### 1 — Reads Every Document

- Typed PDFs (processed instantly)
- Scanned / handwritten PDFs (automatically detected, read using OCR)
- Large combined records (a 71-page multi-section hospital file is split into logical sections automatically)

### 2 — Builds a Knowledge Base with Provenance

Every extracted piece of information is tagged with **where it came from**: which document, which page. Nothing is invented. A value with no source is rejected — not guessed.

### 3 — Plans and Works Through a Checklist

The agent builds a task queue of everything needed in a complete discharge summary and works through it step by step:

```
✓ Extract patient demographics
✓ Find admission and discharge dates
✓ Identify diagnoses (all documents, not just one)
✓ Collect all allergies
✓ List admission medications → discharge medications
✓ Compute what changed (added / removed / dose adjusted)
✓ Check all discharge medications for dangerous interactions
✓ Find follow-up instructions
✓ Find pending lab results
✓ Synthesise hospital course narrative
✓ Validate every field has a cited source
```

If something is still missing after the first pass, the agent **replans and retries** with a broader search strategy.

### 4 — Detects When Documents Disagree

When two documents say different things about the same field, DischargePilot flags it as a **CONFLICT** — showing both values with their source documents — rather than silently picking one.

| Example conflict detected in a real patient file: |
|---|
| Admission note: "Probable NSTEMI vs unstable angina" |
| Progress note Day 2: "NSTEMI with mild systolic dysfunction" |
| Discharge summary: "Non-ST Elevation Myocardial Infarction (NSTEMI)" |

All three are shown. The doctor decides the correct primary diagnosis.

### 5 — Catches Dangerous Drug Combinations

All discharge medications are cross-referenced against a clinical drug interaction database.

**Example from a real test patient:**
> ⚠️ **HIGH** — Digoxin + Amiodarone  
> Amiodarone increases digoxin plasma levels significantly. Dose reduction and level monitoring required.

High-severity interactions are flagged and require human acknowledgement before the summary is finalised.

### 6 — Generates a Structured Draft

The output is a **13-section structured draft** — not a free-text paragraph that a doctor has to fact-check line by line:

| Section | Status |
|---|---|
| Patient demographics | 🟢 Found (with source) |
| Admission date | 🟢 Found |
| Discharge date | 🟡 **Missing** — clinician review required |
| Principal diagnosis | 🔴 **Conflict** — 3 competing values shown |
| Medications (9 at discharge) | 🟢 Found with dose + route + frequency |
| Drug interactions | 🔴 **HIGH: Digoxin + Amiodarone** |
| Allergies | 🟢 Aspirin (Angioedema), Codeine (Nausea) |
| Follow-up instructions | 🟢 Found |
| Pending results | 🟡 Thyroid panel awaiting |

### 7 — Learns From Doctor Corrections

After the doctor reviews and corrects the draft, DischargePilot measures how much editing was required using an **edit-distance reward score**:

```
Iteration 1: 96.1% reward  →  1 correction applied by doctor
Iteration 2: 100.0% reward →  agent already correct — no edits needed
Iteration 3: 100.0% reward →  agent already correct — no edits needed
```

Each correction is stored in memory and applied in the next run automatically.

### 8 — Full Transparency (Trace Log)

Every step the agent took is recorded and available for review:

```
Step 1  → Extract demographics       1.3ms  ✓ Found: name, DOB, MRN, gender
Step 5  → Check allergy docs         0.1ms  ✓ Found: 2 allergies
Step 9  → Drug interactions          0.0ms  ✓ 1 interaction (1 HIGH)
Step 15 → Safety validation          4.1ms  ✓ Passed — all fields have source evidence
Step 16 → Replan: discharge date    0.1ms  ✓ Still missing — clinician flagged
```

The doctor or evaluator can see exactly how every conclusion was reached.

---

## What the Doctor Sees

### Screen 1 — Upload

Drag-and-drop patient PDF files. The system detects document types automatically (admission note, lab report, discharge summary, etc.). Click **Analyse**.

### Screen 2 — Agent Progress

While the agent works, a live timeline shows each reasoning step as it happens. This is not a black box — the agent's thinking is visible in real time.

### Screen 3 — Review & Export

A structured 13-section draft:

- **🟢 Green** — verified value with source citation and confidence score
- **🟡 Amber** — not found in any document; clinician fills in
- **🔴 Red** — conflict detected; all competing values shown with sources

Four tabs:
1. **Discharge Summary** — the main draft
2. **Review Flags** — all issues requiring doctor decision
3. **Agent Trace** — full step-by-step reasoning log
4. **Learning Loop** — reward improvement chart over 3 iterations

Click **Export PDF** to generate a printable clinical document.

---

## A Real-World Test

| Patient | H D Nagaraja, 45y/M — Sarji Specialty Hospital |
|---|---|
| Input | 71-page scanned PDF (image only, no embedded text) |
| Pipeline | OCR detected → EasyOCR on all 71 pages → patient ID filter → 24 logical sections |
| Agent steps | 20 |
| Correctly extracted | Name, DOB, MRN, admission date, follow-up date, pending creatinine result, urine culture result |
| Correctly flagged | Discharge date MISSING; attending physician CONFLICT; principal diagnosis CONFLICT |

---

## The Four Safety Layers

| Layer | What it prevents |
|---|---|
| **Source-only extraction** | Hallucination — no source = field rejected, not guessed |
| **Conflict detection** | Silent errors — disagreeing documents are surfaced, not hidden |
| **Drug interaction check** | Missed dangerous combinations |
| **Safety validator** | Final pass — every FOUND field must cite a real document |

---

## Honest Limitations

- **Clinical decisions remain with the doctor.** The agent surfaces information; it does not make clinical judgements.
- **Scanned documents have lower accuracy.** OCR on handwritten notes introduces noise.
- **Without a real LLM API key**, the hospital course narrative is a template. With Claude or GPT-4 configured, it becomes a proper synthesised paragraph.
- **PDF only.** DOCX, images, and other formats are not currently supported.

---

## Summary

DischargePilot is an agentic AI system that:

- Reads patient documents **carefully** — not carelessly
- Tracks **exactly** where every piece of information came from  
- **Flags problems** rather than hiding them
- **Never invents** information it did not find in the source documents
- Gives the doctor a structured, reviewable draft — not a finished document that bypasses human judgement

The goal is not to replace the doctor. It is to do the tedious information-gathering work so the doctor can focus on reviewing and approving rather than hunting through dozens of documents.

---

*Built as an Agentic AI System Design challenge demonstrating: agent loops, planning & replanning, tool calling, conflict detection, safety guardrails, observability, and human-in-the-loop workflows.*
