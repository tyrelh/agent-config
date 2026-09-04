"""Collect local PR-history evidence for developer preference discovery.

The script intentionally writes only to .local/pr-analysis/, which is ignored by
Git. It gathers comments and reviews written by the developer (on any PR, including
their own) through the GitHub CLI and produces a compact Markdown report the AI can
use to propose candidate rules. The report is evidence only; rules are saved only
after the developer confirms them.

Example:
  python3 analyze_prs.py --repo OWNER/REPO
  python3 analyze_prs.py --org ORG
"""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import json
import os
import re
import subprocess
import sys
from typing import Any

import generate as preferences

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, ".local", "pr-analysis")
PR_MINING_INDEX = os.path.join(OUT_DIR, "index.json")
COMPACT_RULES = os.path.join(HERE, ".local", "RULES.compact.md")
FULL_RULES = os.path.join(HERE, ".local", "RULES.md")


def now_slug() -> str:
    """now_slug returns a filesystem-safe UTC timestamp."""
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def run_gh(args: list[str]) -> str:
    """run_gh executes gh and returns stdout, failing with stderr context."""
    result = subprocess.run(["gh", *args], check=False, capture_output=True, text=True)
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"gh {' '.join(args)} failed: {message}")
    return result.stdout


def login_of(entry: Any) -> str:
    """login_of extracts a GitHub login from nested author/user shapes."""
    if not isinstance(entry, dict):
        return ""
    for key in ("author", "user"):
        nested = entry.get(key)
        if isinstance(nested, dict) and nested.get("login"):
            return str(nested["login"])
    if entry.get("login"):
        return str(entry["login"])
    return ""


def repo_name(entry: Any) -> str:
    """repo_name extracts OWNER/REPO from a search result repository field."""
    if isinstance(entry, dict):
        return str(entry.get("nameWithOwner") or "")
    return ""


def search_prs_with_author_comments(scope_args: list[str], author: str, limit: int) -> list[dict[str, Any]]:
    """search_prs_with_author_comments finds PRs the author reviewed or commented on."""
    fields = "number,title,url,author,repository,state,updatedAt"
    seen: dict[str, dict[str, Any]] = {}

    for qualifier, flag in (("reviewed-by", "--reviewed-by"), ("commenter", "--commenter")):
        remaining = max(limit - len(seen), 0)
        if remaining <= 0:
            break
        raw = run_gh([
            "search",
            "prs",
            *scope_args,
            flag,
            author,
            "--limit",
            str(remaining + len(seen)),
            "--json",
            fields,
        ])
        for item in json.loads(raw):
            url = str(item.get("url") or "")
            if not url or url in seen:
                continue
            repository = repo_name(item.get("repository"))
            if not repository:
                continue
            seen[url] = {
                "number": item.get("number"),
                "title": item.get("title") or "",
                "url": url,
                "state": item.get("state") or "",
                "updatedAt": item.get("updatedAt") or "",
                "prAuthor": login_of(item),
                "repository": repository,
                "discovery": qualifier,
            }
            if len(seen) >= limit:
                break

    return list(seen.values())[:limit]


def fetch_author_discussion(repo: str, number: int, author: str) -> dict[str, list[dict[str, Any]]]:
    """fetch_author_discussion returns only comments/reviews written by author on one PR."""
    author_l = author.lower()
    comments: list[dict[str, Any]] = []
    reviews: list[dict[str, Any]] = []
    review_comments: list[dict[str, Any]] = []

    try:
        raw = run_gh([
            "pr",
            "view",
            str(number),
            "--repo",
            repo,
            "--json",
            "comments,reviews",
        ])
        payload = json.loads(raw)
    except RuntimeError:
        payload = {"comments": [], "reviews": []}

    for item in payload.get("comments") or []:
        if login_of(item).lower() != author_l:
            continue
        body = str(item.get("body") or "").strip()
        if not body:
            continue
        comments.append({
            "author": {"login": author},
            "body": body,
            "createdAt": item.get("createdAt") or "",
            "url": item.get("url") or "",
            "kind": "issue_comment",
        })

    for item in payload.get("reviews") or []:
        if login_of(item).lower() != author_l:
            continue
        body = str(item.get("body") or "").strip()
        state = str(item.get("state") or "")
        if not body and state in {"", "PENDING"}:
            continue
        reviews.append({
            "author": {"login": author},
            "body": body,
            "state": state,
            "submittedAt": item.get("submittedAt") or "",
            "kind": "review",
        })

    try:
        inline_raw = run_gh([
            "api",
            f"repos/{repo}/pulls/{number}/comments",
            "--paginate",
        ])
        inline_items = json.loads(inline_raw) if inline_raw.strip() else []
    except RuntimeError:
        inline_items = []

    if not isinstance(inline_items, list):
        inline_items = []

    for item in inline_items:
        if login_of(item).lower() != author_l:
            continue
        body = str(item.get("body") or "").strip()
        if not body:
            continue
        review_comments.append({
            "author": {"login": author},
            "body": body,
            "path": item.get("path") or "",
            "line": item.get("line") or item.get("original_line"),
            "createdAt": item.get("created_at") or "",
            "url": item.get("html_url") or "",
            "kind": "review_comment",
        })

    return {
        "comments": comments,
        "reviews": reviews,
        "reviewComments": review_comments,
    }


def fetch_author_comments(
    scope_args: list[str],
    author: str,
    limit: int,
) -> tuple[list[dict[str, Any]], list[str]]:
    """fetch_author_comments mines only the author's comments on any matching PRs."""
    candidates = search_prs_with_author_comments(scope_args, author, limit)
    prs: list[dict[str, Any]] = []
    failures: list[str] = []

    for item in candidates:
        repo = str(item["repository"])
        number = int(item["number"])
        try:
            discussion = fetch_author_discussion(repo, number, author)
        except RuntimeError as exc:
            failures.append(f"{repo}#{number}: {exc}")
            continue

        own_count = (
            len(discussion["comments"])
            + len(discussion["reviews"])
            + len(discussion["reviewComments"])
        )
        if own_count == 0:
            continue

        prs.append({
            **item,
            "comments": discussion["comments"],
            "reviews": discussion["reviews"],
            "reviewComments": discussion["reviewComments"],
            "authorCommentCount": own_count,
        })

    return prs, failures


def words(text: str) -> list[str]:
    """words returns simple lowercase terms useful for frequency counts."""
    stop = {
        "the", "and", "for", "with", "from", "that", "this", "into", "when", "where",
        "use", "uses", "using", "add", "adds", "added", "update", "updates", "fix",
        "fixes", "make", "makes", "remove", "removes", "change", "changes", "to",
        "of", "in", "on", "a", "an", "is", "are", "be", "by", "as", "it",
        "you", "we", "i", "im", "just", "also", "like", "think", "dont", "does",
        "can", "could", "should", "would", "will", "not", "but", "if", "or", "so",
    }
    return [term for term in re.findall(r"[a-z][a-z0-9_-]{2,}", text.lower()) if term not in stop]


def body_text(items: Any) -> str:
    """body_text extracts body text from comment or review entries."""
    parts = []
    for item in items or []:
        if isinstance(item, dict) and item.get("body"):
            parts.append(str(item["body"]))
    return "\n".join(parts)


def all_author_bodies(pr: dict[str, Any]) -> str:
    """all_author_bodies joins every mined author comment body on a PR."""
    return "\n".join([
        body_text(pr.get("comments")),
        body_text(pr.get("reviews")),
        body_text(pr.get("reviewComments")),
    ])


def summarize(prs: list[dict[str, Any]]) -> dict[str, Any]:
    """summarize extracts repeatable signals from the author's own comments."""
    comment_terms: Counter[str] = Counter()
    review_terms: Counter[str] = Counter()
    inline_terms: Counter[str] = Counter()
    paths: Counter[str] = Counter()
    pr_authors: Counter[str] = Counter()
    repos: Counter[str] = Counter()
    kinds: Counter[str] = Counter()
    review_states: Counter[str] = Counter()

    total_comments = 0
    for pr in prs:
        repos[str(pr.get("repository") or "unknown")] += 1
        pr_authors[str(pr.get("prAuthor") or "unknown")] += 1
        comment_terms.update(words(body_text(pr.get("comments"))))
        review_terms.update(words(body_text(pr.get("reviews"))))
        inline_terms.update(words(body_text(pr.get("reviewComments"))))
        for item in pr.get("comments") or []:
            kinds["issue_comment"] += 1
            total_comments += 1
        for item in pr.get("reviews") or []:
            kinds["review"] += 1
            total_comments += 1
            if item.get("state"):
                review_states[str(item["state"])] += 1
        for item in pr.get("reviewComments") or []:
            kinds["review_comment"] += 1
            total_comments += 1
            path = str(item.get("path") or "")
            if path:
                paths[path] += 1

    return {
        "authorCommentCount": total_comments,
        "prsWithAuthorComments": len(prs),
        "commentTerms": comment_terms.most_common(25),
        "reviewTerms": review_terms.most_common(25),
        "inlineCommentTerms": inline_terms.most_common(25),
        "commentKinds": kinds.most_common(),
        "reviewStates": review_states.most_common(),
        "prAuthors": pr_authors.most_common(25),
        "repositories": repos.most_common(25),
        "paths": paths.most_common(25),
    }


def load_existing_rules() -> list[str]:
    """load_existing_rules returns current local rules for duplicate checks."""
    path = COMPACT_RULES if os.path.exists(COMPACT_RULES) else FULL_RULES
    rules: list[str] = []
    if not os.path.exists(path):
        return rules
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            compact = re.match(r"^-\s+\[[^\]]+\]\s+\[[^\]]+\]\s+(.*)$", line)
            bullet = re.match(r"^-\s+(.*)$", line)
            if compact:
                rules.append(compact.group(1).strip())
            elif bullet:
                rules.append(bullet.group(1).strip())
    return rules


def matching_rules(existing_rules: list[str], terms: list[str]) -> list[str]:
    """matching_rules returns existing rules that contain any comparison term."""
    matches = []
    for rule in existing_rules:
        lowered = rule.lower()
        if any(term in lowered for term in terms):
            matches.append(rule)
    return matches[:3]


def candidate_entry(rule: str, basis: str, overlaps: list[str]) -> dict[str, Any]:
    """candidate_entry creates a duplicate-aware rule candidate."""
    return {
        "rule": rule,
        "basis": basis,
        "status": "covered" if overlaps else "candidate",
        "overlaps": overlaps,
    }


def analyze_candidate_rules(prs: list[dict[str, Any]], summary: dict[str, Any]) -> list[dict[str, Any]]:
    """analyze_candidate_rules proposes non-duplicate candidates from author comments."""
    existing_rules = load_existing_rules()
    bodies = [all_author_bodies(pr) for pr in prs]
    joined = "\n".join(bodies).lower()

    def count_hits(patterns: list[str]) -> int:
        return sum(1 for body in bodies if any(re.search(pat, body, re.IGNORECASE) for pat in patterns))

    small_pr_hits = count_hits([r"\bsplit\b", r"\bsmaller\b", r"\btoo big\b", r"\bseparate (pr|change)"])
    naming_hits = count_hits([r"\brename\b", r"\bnaming\b", r"\bcall(ed)? it\b", r"\bname is\b"])
    generated_hits = count_hits([r"\bgenerated\b", r"\bopenapi\b", r"\bspec\b", r"\bhand-?roll"])
    test_hits = count_hits([r"\btest(s|ing)?\b", r"\bgiven\b.*\bwhen\b", r"\bcoverage\b"])
    yagni_hits = count_hits([r"\bfuture pr\b", r"\bnext pr\b", r"\bout of scope\b", r"\bdo we need\b", r"\byagni\b"])
    reuse_hits = count_hits([r"\breuse\b", r"\bduplicat", r"\balready (have|exists|have this)\b", r"\bshared\b"])

    candidates = [
        candidate_entry(
            "Keep PRs small and single-purpose — ask authors to split unrelated or oversized changes.",
            f"Author comments mention splitting/size on {small_pr_hits} of {len(prs)} PRs. Top terms include: {summary.get('inlineCommentTerms', [])[:5]}.",
            matching_rules(existing_rules, ["small", "single-purpose", "split", "scope creep"]),
        ),
        candidate_entry(
            "Push for intent-revealing names and consistent domain terminology in review.",
            f"Naming/clarity themes appear in author comments on {naming_hits} PRs.",
            matching_rules(existing_rules, ["intent-revealing", "terminology", "rename", "reader"]),
        ),
        candidate_entry(
            "Prefer generated OpenAPI/types over hand-maintained duplicates when reviewing API or UI option lists.",
            f"Generated/spec themes appear in author comments on {generated_hits} PRs.",
            matching_rules(existing_rules, ["openapi", "generated", "hand-roll", "hand-define"]),
        ),
        candidate_entry(
            "Ask for tests when new logic lands, especially reusable GIVEN/WHEN/THEN coverage.",
            f"Testing themes appear in author comments on {test_hits} PRs.",
            matching_rules(existing_rules, ["unit tests", "given / when / then", "testing"]),
        ),
        candidate_entry(
            "Challenge speculative additions in review — prefer deferring non-essential work to a follow-up PR.",
            f"Scope/YAGNI themes appear in author comments on {yagni_hits} PRs. Reuse/duplication themes on {reuse_hits} PRs.",
            matching_rules(existing_rules, ["yagni", "do we actually need", "future", "duplicate"]),
        ),
        candidate_entry(
            "When reviewing, leave concrete actionable feedback on the diff rather than only approving.",
            f"Mined {summary.get('authorCommentCount', 0)} author comments across {len(prs)} PRs "
            f"(kinds: {dict(summary.get('commentKinds') or [])}).",
            matching_rules(existing_rules, ["never reply to pr comments", "review feedback"]),
        ),
    ]

    # Drop empty-signal candidates that have zero hits and no distinctive basis.
    filtered = []
    for candidate in candidates:
        if candidate["status"] == "covered":
            filtered.append(candidate)
            continue
        if any(x in candidate["basis"] for x in (" on 0 ", " on 0 of ")):
            # Keep the actionable-feedback candidate even when theme hits are low.
            if "Mined" in candidate["basis"]:
                filtered.append(candidate)
            continue
        filtered.append(candidate)
    if "openapi" in joined or "generated" in joined:
        pass
    return filtered or candidates


def render_candidate_analysis(candidates: list[dict[str, Any]]) -> list[str]:
    """render_candidate_analysis returns Markdown for duplicate-aware candidates."""
    lines = [
        "## Candidate Rule Analysis",
        "",
        "These candidates are compared with existing local rules. Save none without developer confirmation.",
        "",
    ]
    for index, candidate in enumerate(candidates, start=1):
        status = "new candidate" if candidate["status"] == "candidate" else "already covered"
        lines.extend([
            f"### {index}. {status}",
            "",
            f"- Candidate: {candidate['rule']}",
            f"- Evidence: {candidate['basis']}",
        ])
        if candidate["overlaps"]:
            lines.append("- Existing overlap:")
            for overlap in candidate["overlaps"]:
                lines.append(f"  - {overlap}")
        lines.append("")
    return lines


def render_markdown(
    subject: str,
    author: str,
    prs: list[dict[str, Any]],
    summary: dict[str, Any],
    candidates: list[dict[str, Any]],
    failures: list[str] | None = None,
) -> str:
    """render_markdown returns a report suitable for AI review."""
    lines = [
        f"# PR Comment Pattern Analysis: {author}",
        "",
        f"- Scope: `{subject}`",
        f"- Mode: author comments only (any PR, including the author's own)",
        f"- PRs with author comments: {len(prs)}",
        f"- Author comments mined: {summary.get('authorCommentCount', 0)}",
        f"- Generated: {preferences.now_iso()}",
        "",
        "## Important",
        "",
        "This report is evidence only. Do not save rules from it unless the developer confirms them.",
        "Before proposing a rule, compare it with `.local/RULES.compact.md` and `.local/RULES.md`; merge, reword, or skip overlapping rules instead of creating duplicates.",
        "Only comments/reviews written by the analyzed author are included. Other reviewers' text is omitted.",
        "",
        "## Recurring Signals",
        "",
    ]

    sections = [
        ("Comment kinds", "commentKinds"),
        ("Review states", "reviewStates"),
        ("Issue-comment terms", "commentTerms"),
        ("Review-body terms", "reviewTerms"),
        ("Inline review-comment terms", "inlineCommentTerms"),
        ("PR authors commented on", "prAuthors"),
        ("Repositories", "repositories"),
        ("Files touched in inline comments", "paths"),
    ]
    for title, key in sections:
        lines.extend([f"### {title}", ""])
        values = summary.get(key) or []
        if not values:
            lines.extend(["- No data", ""])
            continue
        for name, count in values:
            lines.append(f"- `{name}`: {count}")
        lines.append("")

    lines.extend(render_candidate_analysis(candidates))

    lines.extend([
        "## Comment Evidence",
        "",
    ])
    for pr in prs:
        own = pr.get("prAuthor") == author
        ownership = "own PR" if own else f"by @{pr.get('prAuthor')}"
        lines.append(
            f"- {pr.get('repository')}#{pr.get('number')} {pr.get('title')} "
            f"({ownership}; {pr.get('authorCommentCount')} comments) ({pr.get('url')})"
        )
        for item in pr.get("comments") or []:
            body = re.sub(r"\s+", " ", str(item.get("body") or "")).strip()
            lines.append(f"  - issue_comment: {body[:400]}")
        for item in pr.get("reviews") or []:
            body = re.sub(r"\s+", " ", str(item.get("body") or "")).strip()
            state = item.get("state") or ""
            prefix = f"review/{state}" if state else "review"
            if body:
                lines.append(f"  - {prefix}: {body[:400]}")
            else:
                lines.append(f"  - {prefix}")
        for item in pr.get("reviewComments") or []:
            body = re.sub(r"\s+", " ", str(item.get("body") or "")).strip()
            path = item.get("path") or ""
            loc = f"{path}:{item.get('line')}" if path else "inline"
            lines.append(f"  - review_comment ({loc}): {body[:400]}")

    if failures:
        lines.extend([
            "",
            "## Fetch Failures",
            "",
        ])
        for failure in failures:
            lines.append(f"- {failure}")

    lines.extend([
        "",
        "## Candidate Rule Questions",
        "",
        "Ask the developer concise yes/no questions before saving anything. Examples:",
        "",
        "- Should I save a rule based on recurring review themes above?",
        "- Should I save a rule about preferred PR size or scope from your review comments?",
        "- Should I save a rule about naming, generated types, or testing feedback you repeat?",
        "",
    ])
    return "\n".join(lines)


def write_reports(
    subject: str,
    author: str,
    prs: list[dict[str, Any]],
    summary: dict[str, Any],
    candidates: list[dict[str, Any]],
    failures: list[str] | None = None,
) -> tuple[str, str]:
    """write_reports writes JSON and Markdown reports under .local/pr-analysis."""
    os.makedirs(OUT_DIR, exist_ok=True)
    slug = f"{author}-{now_slug()}"
    json_path = os.path.join(OUT_DIR, f"{slug}.json")
    markdown_path = os.path.join(OUT_DIR, f"{slug}.md")
    payload = {
        "scope": subject,
        "author": author,
        "mode": "author_comments",
        "generatedAt": preferences.now_iso(),
        "summary": summary,
        "candidateAnalysis": candidates,
        "prs": prs,
        "failures": failures or [],
    }
    preferences.write_json(json_path, payload)
    with open(markdown_path, "w", encoding="utf-8") as handle:
        handle.write(render_markdown(subject, author, prs, summary, candidates, failures))
    return json_path, markdown_path


def append_mining_history(
    subject: str,
    author: str,
    limit: int,
    prs: list[dict[str, Any]],
    summary: dict[str, Any],
    json_path: str,
    markdown_path: str,
) -> None:
    """append_mining_history records a local PR-mining run for the dashboard."""
    os.makedirs(OUT_DIR, exist_ok=True)
    history = preferences.load_json(PR_MINING_INDEX, [])
    history = [
        entry for entry in history
        if not (entry.get("repo") == subject and entry.get("author") == author)
    ]

    history.append({
        "minedAt": preferences.now_iso(),
        "repo": subject,
        "author": author,
        "mode": "author_comments",
        "limit": limit,
        "mergedPrs": len(prs),
        "authorComments": summary.get("authorCommentCount", 0),
        "json": os.path.relpath(json_path, HERE),
        "markdown": os.path.relpath(markdown_path, HERE),
    })
    preferences.write_json(PR_MINING_INDEX, history)


def regenerate_preferences() -> None:
    """regenerate_preferences refreshes local dashboard artifacts after mining."""
    try:
        preferences.write_artifacts(preferences.build_data())
    except Exception as exc:
        print(f"warning: regenerate preferences failed: {exc}", file=sys.stderr)


def parse_args() -> argparse.Namespace:
    """parse_args parses CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Analyze the developer's own PR comments (on any PR) for preference patterns."
    )
    scope = parser.add_mutually_exclusive_group(required=True)
    scope.add_argument("--repo", help="GitHub repository in OWNER/REPO format.")
    scope.add_argument("--org", help="GitHub organization whose pull requests should be searched.")
    parser.add_argument("--author", help="GitHub username whose comments to mine.")
    parser.add_argument(
        "--limit",
        type=int,
        default=100,
        help="Maximum PRs to inspect where the author commented or reviewed (default: 100).",
    )
    return parser.parse_args()


def main() -> int:
    """main fetches author comments and writes local reports."""
    args = parse_args()
    try:
        author = args.author or preferences.infer_github_username()
        if args.org:
            scope_args = ["--owner", args.org]
            subject = args.org
        else:
            scope_args = ["--repo", args.repo]
            subject = args.repo

        prs, failures = fetch_author_comments(scope_args, author, args.limit)
        summary = summarize(prs)
        candidates = analyze_candidate_rules(prs, summary)
        json_path, markdown_path = write_reports(subject, author, prs, summary, candidates, failures)
        append_mining_history(subject, author, args.limit, prs, summary, json_path, markdown_path)
        regenerate_preferences()
    except (RuntimeError, ValueError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    print(f"mode: author comments only")
    print(f"prs with author comments: {len(prs)}")
    print(f"author comments mined: {summary.get('authorCommentCount', 0)}")
    print(f"fetch failures: {len(failures)}")
    print(f"json: {json_path}")
    print(f"markdown: {markdown_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
