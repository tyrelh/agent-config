---
name: grill-me
description: Grill the user relentlessly about a plan, decision, or idea. Use when the user wants to stress-test their thinking, or uses any 'grill' trigger phrases.
reference: Adapted from Matt Pocock https://github.com/mattpocock/skills/
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round, giving your recommended answer for each. Then wait for the user's answers before the next round.

Ask with the harness's native question tool when it has one (`AskUserQuestion` in Claude Code, `request_user_input` in Codex):

- Send the round in groups of 2-4 questions per call. Split a larger frontier across consecutive calls; a frontier of one is a single question.
- Give each question 1-3 concrete options, at least 2 if the tool requires it. Put your recommended option first and end its label with "(Recommended)". Use the option descriptions for the tradeoffs.
- The last option is always free-form, so the user can give their own answer. Most tools add an "Other" choice automatically; add one yourself only when the tool doesn't.
- Put the context the user needs to decide in the question text, not in a message before the call.

Without a native question tool, format the round as text, numbering each question:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
