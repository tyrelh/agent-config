# Developer Preferences

This is the full editable template. Agents should normally read the generated compact file at
`.local/RULES.compact.md` instead of this full document.

Initialize local rules with:

```bash
python3 generate.py init
```

The sections below are intentionally generic. The AI should add or rewrite rules only after the
developer confirms a proposed rule. Developers can also edit their local `.local/RULES.md`
directly, then run `python3 generate.py`.

---

## Languages & Stack

- **Primary languages**: TypeScript, Go
- **Package manager**: Follow the project's established package manager
- **Indentation**: Follow the project's formatter
- **Semicolons**: Follow the project's ESLint / Prettier config

---

## TypeScript Standards

- Use path aliases when the project has them configured
- Avoid `any`; type values explicitly when practical
- Prefer `async/await` over `.then()` chains
- Prefer named exports unless the project convention says otherwise
- Do not use `console.log` in production code; use the project's logger

---

## Go Standards

- Propagate `context.Context` down request call chains
- Use the project's structured logger instead of `fmt.Println` for logging
- Return errors instead of panicking in normal control flow

---

## Testing

- Write tests for meaningful behavior, not trivial data containers
- Use the project's standard test entrypoint
- Keep shared setup reusable instead of duplicating it across tests

---

## Git & Commits

- Use conventional commit style when the project does
- Never commit secrets, `.env` files, or credentials
- Never add AI attribution trailers or generated-by footers unless the developer explicitly requests them

---

## Documentation

- Keep architecture docs focused on design, concepts, and diagrams
- Follow the established documentation structure and placement

---

## Security

- Never log secrets or sensitive data
- Pin third-party CI actions and tools when the project requires reproducible builds

---

## Code Quality & Scope

- Keep changes small and single-purpose
- Reuse existing components, helpers, and patterns before adding new ones
- Avoid speculative fields, types, endpoints, or configuration
- Fix lint issues at the source instead of silencing linters
- Use intent-revealing names

---

## API & Naming Clarity

- Use established domain terminology
- Do not leak internal implementation details into API contracts
- Model closed sets of values as enums or defined types when appropriate

---

## Architecture

### Frontend

- Prefer functional components and hooks in React projects
- Follow feature-based or domain-based folder organization when present

### Backend

- Keep controllers thin
- Put business logic in services or domain layers
- Prefer OpenAPI or the project's API contract source of truth when one exists
- Use generated types and schemas instead of hand-writing generated boilerplate

---

## Hard Rules

### Always

- Use the project's centralized command entrypoints
- Follow existing formatter and lint configuration

### Never

- Commit secrets
- Add unrelated refactors to a focused change
- Leave commented-out dead code in commits
