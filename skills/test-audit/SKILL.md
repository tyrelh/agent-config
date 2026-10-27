---
name: test-audit
description: Audit the tests added in uncommitted changes, or in the branch diff vs main when the tree is clean, for correctness and value. Flags tautological, unfalsifiable, brittle, off-target, and happy-path-only tests, and tests that exercise a library instead of our code, then walks each proposed change with the user for accept, reject, or revise. Use when asked to audit, gate, or sanity-check new tests, or "are these tests worth keeping".
argument-hint: "[<target>]  (branch, ref range, or path. Defaults to uncommitted changes, or the branch diff vs main when the tree is clean)"
---

# test-audit

A test earns its place by going **red** on a credible regression in our code that nothing else already catches, and doing it fast. Every added test is a candidate until it shows that. The goal is a suite that stays fast, concise, and high value, with coverage that means something.

Scope is **added tests only**: new test files, and new test cases inside existing files. An existing test whose body changed is out of scope unless the change replaced it with what is effectively a new test. Pre-existing tests are context for duplicate checks, never findings.

The user decides every change. Steps 1 to 5 are read-only. Step 6 walks each proposed change with the user, and a file changes only when the user accepts that specific change. Accepted changes stay loose in the working tree: the skill never runs `git add`, `git commit`, `git stash`, or `git push`, and never touches the index.

## 1. Scope the diff

Pick the target in this order: an argument if one was passed, then uncommitted work if there is any, then the branch diff vs the default branch. Write the diff once to the scratchpad and read from that file from here on.

```bash
git status --porcelain
DIFF=<scratchpad>/test-audit.diff
if [ -n "$(git status --porcelain)" ]; then
  git diff HEAD > "$DIFF"
  git ls-files -o --exclude-standard -z \
    | xargs -0 -r -I{} git diff --no-index -- /dev/null {} >> "$DIFF"   # untracked files; non-zero exit is normal
else
  BASE=$(git merge-base origin/main HEAD 2>/dev/null || git merge-base main HEAD)
  git diff "$BASE"...HEAD > "$DIFF"
fi
```

Say in one line which target you took. If the diff is empty, say so and stop.

## 2. Inventory the added tests

List every added test case with its `file:line` and name. A test case is the smallest unit the runner reports on its own:

- Go: `func TestX(t *testing.T)`, and each `t.Run` subtest or table row added to an existing table
- TS/JS: `it(...)` / `test(...)`, including `.each` rows
- Groovy/Spock: feature methods (`def "..."()`) and added `where:` rows
- Java/JUnit: `@Test` / `@ParameterizedTest` methods and added parameter rows

A new table row or `where:` row counts as an added test even when the function around it already existed.

Done when every added test case in the diff is on the list. If there are none, say so and stop.

When this session wrote the tests being audited, your own intent fills gaps the code leaves. Run steps 3 and 4 in a fresh subagent given the diff file path and the inventory, not your account of what the tests do, then verdict its findings yourself.

## 3. Gather context per test

For each test, read before judging:

- the complete test, its setup, fixtures, and helpers
- the production code it exercises, including every branch in the function under test
- sibling tests at the same boundary, to spot duplicates

Done when you can name, for each test, the production function it targets and the branches that function has.

## 4. Apply the rubric

Run every test against every rule below. For each one, try to name the **break**: a specific, plausible change to production code that turns this test red. A test with no nameable break pins nothing.

Then judge the test on its assertions, never on its name.

**Correctness**
- **Wrong expectation**: the asserted value or behaviour contradicts what the production code or the ticket says should happen, so the test locks in a bug.
- **Wrong target**: the test claims to cover X but the code path it actually reaches is Y (an earlier guard rejects the input, a mock short-circuits the call, the setup never reaches the branch).

**Value**
- **Tautological**: the expected value comes from the code under test, from a mock configured in the same test, or from the fixture the test itself built. Asserting the mock returned what the mock was told to return.
- **Hollow assertion**: no assertion, only "does not throw" on a path that cannot throw, `assertNotNull` on something that cannot be null, a type check the compiler already enforces, or an assertion so loose (`len > 0`, `contains("error")`) that most broken outputs still pass.
- **Unfalsifiable**: passes regardless of the code. Assertions inside a callback or loop that never runs, a swallowed error, an async assertion that is never awaited, a negative test that passes because a different guard rejects the input, a condition that skips the test in CI.
- **Off-target**: exercises something that is not business logic: getters and setters, constructors, constants, generated code, DI or framework wiring, a config value restated from the config file.
- **Library test**: the behaviour asserted belongs to a third-party library, the language, or the framework (JSON marshalling, an ORM's save, a router's matching, a validation annotation firing). Our code is a pass-through. Keep it only when it pins how *we* configured the library and a credible misconfiguration would turn it red.
- **Duplicate**: an existing test already pins the same contract at the same boundary. Name the existing test.

**Robustness**
- **Brittle**: goes red on a change that is not a regression. Signals: `toHaveBeenCalledWith` or `verify` on internal collaborators, exact call counts or ordering that is not observable behaviour, exact error or log message strings, whole-object snapshots, map or set iteration order, wall-clock time, randomness without a seed, shared mutable state between tests.
- **Slow**: real sleeps, real network or external services, a full app or database boot where a unit boundary would do, or setup far heavier than the behaviour needs.

**Coverage shape**
- **Happy path only**: the production code has branches the added tests never reach. Name each untested branch concretely, from the code you read in step 3: the error return, the empty input, the boundary value (zero, max, off-by-one at the limit), the duplicate, the unauthorised caller, the concurrent call. List only branches that exist in the code; a generic checklist of edge cases is noise.

Done when every test has been checked against every rule, and each test has either a named break or a finding saying why it has none.

## 5. Verdict

Give each test one verdict:

- **Keep**: has a named break, no findings that matter.
- **Fix**: real value buried under a problem; say the specific change (assert at the boundary instead of on the mock, add the missing branch, seed the clock).
- **Cut**: no named break, or fully duplicated. Name the keeper test when it is a duplicate.

Tag each finding **confirmed** when you can quote the line that proves it (the assertion reads back the mock, the duplicate is named), or **plausible** when the mechanism is real but you have not traced it end to end; say what would confirm it. Run the test when that settles a plausible finding cheaply.

## 6. Preview

Turn every Cut and Fix into one proposed change, and every missing edge case into a proposed new test case. Rank them: confirmed before plausible, then Cut, Fix, and missing edge cases, then larger net line change first.

Show a numbered table of `#`, `file:line`, a one-line summary, the rule(s), the action (Cut, Fix, Add), and the tag (confirmed or plausible). Put the estimated total `net: <±N> lines` under it.

Under the table, list the Keep tests one line each, with the named break as the whole justification:

```
Keep
- path/to/baz_test.go:88 TestBaz_RateLimit: goes red if the window check at baz.go:31 flips < to <=.
```

If there are no proposed changes, say `Tests earn their place. Ship.` and stop.

## 7. Walk the proposed changes

One at a time, in rank order. Present each in exactly this order:

1. Header: `[n/total] <one-line summary>`, followed by `path/to/file_test.ext:123` and the rule(s).
2. Tag: confirmed or plausible.
3. Summary: two or three sentences covering what the test fails to pin, the evidence (quote the line), and for a plausible finding, what is uncertain.
4. Suggested action: Cut, Fix, or Add, with one line on what the change does. For a Cut that is a duplicate, name the keeper test.
5. The diff: copy the test file to the scratchpad, edit the copy, and show `diff -u <repo file> <copy>` as a fenced ```diff block. Do not apply it. `git diff --no-index` mangles the path headers when one side is outside the repo; use `diff -u` for display and `git diff --no-index --numstat` only for the line counts.
6. Net lines: `+<added> / -<removed> (net <±N>)` for the proposed patch.
7. Ask: accept (`a`), reject (`r`), or revise. Treat a bare `a` as accept and a bare `r` as reject. Wait for the answer, and ask about one change at a time.

On accept:

- Apply the patch by copying the scratchpad file over the test file.
- Run the narrowest test command that covers the changed file. A Fix or Add should pass. Then prove the named break: back up the production file to the scratchpad, apply the break, rerun the same command and expect red, then restore from the backup and confirm `git diff --stat -- <file>` shows nothing new. Restore from the backup, never `git checkout`, so uncommitted work in that file survives. Report the clean and broken results. If the clean run fails or the break stays green, say so and ask whether to revert the edit, revise it, or keep going.
- Say in one line what changed and the net line count, then move to the next change.

On reject: note it and move on.

On revise: take their direction, show the revised diff and net lines, and ask again.

## 8. Wrap up

- List the changes applied, `file:line` and one line each, with the total `net: <±N> lines`.
- List rejected changes, one line each.
- State plainly that everything is loose in the working tree: nothing staged, nothing committed, nothing pushed. Point the user at `git diff` to read the whole pass at once.
