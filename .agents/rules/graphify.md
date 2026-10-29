---
trigger: model_decision
description: Optional reference to graphify knowledge graph at graphify-out/ for cross-module architecture questions, dependency audits, or whole-codebase caller/callee tracing.
---

## graphify

This project has a pre-built knowledge graph at `graphify-out/`.

### Guidelines:
- **Architecture & Cross-Module Audits**: Use `graphify path "<A>" "<B>"` or `graphify explain "<concept>"` when analyzing multi-module dependencies, cross-system call chains, or ADR connections.
- **Local & UI Features**: Do NOT invoke graphify for local UI styling, view adjustments, or self-contained file edits. Use direct ripgrep (`rg`) and batched `read_file` instead.
- **Reporting**: Consult `graphify-out/GRAPH_REPORT.md` or `graphify-out/wiki/` only for broad architectural reviews or macro impact assessments.
