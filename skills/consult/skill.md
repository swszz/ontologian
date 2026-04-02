---
name: ontologian:consult
description: Use when the user runs /ontologian:consult to explicitly start a Palantir-grade ontology consulting and construction session.
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

## Steps

### Step 1: Capture initial context

If the user provided arguments or requirements text along with the command, store them as
`initial_context` to pass to the agent.

### Step 2: Launch the consulting agent

Activate the `ontology-consultant` agent in explicit mode.
Pass `initial_context` if available so the agent can skip redundant prompts.

The agent will handle the complete consulting workflow:
Phase 0 (Scope) → Phase 1 (Discovery) → Phase 2 (Modeling) → Phase 3 (Design) → Phase 4 (Construction) → Phase 5 (Delivery)
