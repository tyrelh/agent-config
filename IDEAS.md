# Ideas

Parking lot for skills and tooling not built yet.

## `/todo` skill — add a task to the Obsidian vault

One-liner: `/todo <text>` appends a task to the vault without leaving the terminal.

Notes:
- `obsidian-cli` skill already exists and handles vault reads/writes and tasks — build on it, don't reinvent.
- Open questions: which note does the task land in (daily note? a fixed inbox?), and does it need tags/due dates or is plain text enough to start.
