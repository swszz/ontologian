---
name: ontologian-consult
description: Use when the user runs /ontologian-consult to explicitly start a Palantir-grade ontology consulting and construction session.
---

# Ontologian — Consult

## Overview

Launch the `ontology-consultant` agent for a guided, end-to-end ontology design and
construction session. The agent covers business discovery, Palantir-pattern semantic layer
design, construction, and governance documentation.

Use this skill as the explicit entry point. The `ontology-consultant` agent also triggers
proactively when the user discusses business requirements, domain modeling, or system design —
so users don't need to know this command exists to benefit from it.

---

## Consulting Workflow Overview

The consulting session runs in 6 sequential phases. Each phase has a defined scope, outputs specific files, and asks targeted questions before proceeding.

| Phase | Name | What the agent asks | Files produced | Session context |
|-------|------|---------------------|----------------|-----------------|
| **Phase 0** | Scope | Domain scope confirmation; start from existing requirements or blank slate? | None | Sets `initial_context` and `scope` for all downstream phases |
| **Phase 1** | Discovery | 5-axis structured interview: entities, relationships, processes, boundaries, governance | None (stored in memory) | Raw domain facts collected |
| **Phase 2** | Modeling | Autonomous — derives Object, Link, Action type candidates using `/ontologian-analyze` rules | None (internal draft) | Candidate types derived from Discovery output |
| **Phase 3** | Design | Reviews candidates against Palantir enrichment patterns: object enrichment, state machine audit, semantic naming, governance metadata | None (internal refinement) | Palantir-grade patterns applied |
| **Phase 4** | Construction | Writes all domain files in dependency order; runs `/ontologian-validate` automatically | `objects/<Name>.yaml` per Object Type, `links/<name>.yaml` per Link Type, `actions/<name>.yaml` per Action Type, `.ontology/domains/_index.yaml` | Files written; validation errors resolved before proceeding |
| **Phase 5** | Delivery | Renders ASCII relationship diagrams; generates final report | `.ontology/CONSULT_REPORT.md` | Session complete |

Full agent specification: `agents/ontology-consultant.md`

---

## Steps

### Step 1: Capture initial context

If the user provided arguments or requirements text along with the command, store them as
`initial_context` to pass to the agent.

### Step 2: Launch the consulting agent

Activate the `ontology-consultant` agent in explicit mode.
Pass `initial_context` if available so the agent can skip redundant prompts.

The agent will handle the complete consulting workflow:
Phase 0 (Scope) → Phase 1 (Discovery) → Phase 2 (Modeling) → Phase 3 (Design) → Phase 4 (Construction) → Phase 5 (Delivery)
