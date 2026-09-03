---
name: handoff
description: Compact the current conversation into a handoff prompt for another agent to pick up.
argument-hint: "What will the next session be used for?"
reference: Adapted from Matt Pocock https://github.com/mattpocock/skills/
---

Write a handoff prompt summarising the current conversation so a fresh agent can continue the work. Output this prompt to the user so they can copy & paste it.

Do not duplicate content already captured in other artifacts (PRDs, plans, ADRs, issues, commits, diffs). Reference them by path or URL instead.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

By default don't assume what next steps will be, simply summarize what's been done. If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
