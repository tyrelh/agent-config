"""Build local rule data and dashboard for developer preferences.

Versioned files provide the workflow and starter template. Developer-specific
rules and generated state live under .local/ so they are not committed.

Run from this skill directory:
  python3 generate.py                       # rebuild .local artifacts
  python3 generate.py init                  # create .local/RULES.md if absent
  python3 generate.py profile [GITHUB_USER] # set local developer identity
  python3 generate.py used "<id-or-substring>"... --reason "short reason"
      [--agent Cursor] [--model "Opus 4.8"] [--project OWNER/REPO]
      # record timestamped rule usage
  python3 generate.py touched --reason "short reason"
      [--agent Cursor] [--model "Grok 4.5"] [--project OWNER/REPO]
      # record a general skill use
"""

from datetime import datetime, timezone
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
LOCAL_DIR = os.path.join(HERE, ".local")
RULES_EXAMPLE = os.path.join(HERE, "RULES.example.md")
RULES = os.path.join(LOCAL_DIR, "RULES.md")
DATA = os.path.join(LOCAL_DIR, "candidates.json")
DASH = os.path.join(LOCAL_DIR, "dashboard.html")
COMPACT = os.path.join(LOCAL_DIR, "RULES.compact.md")
REMOVED = os.path.join(LOCAL_DIR, "removed.json")
PROFILE = os.path.join(LOCAL_DIR, "profile.json")
PR_MINING_INDEX = os.path.join(LOCAL_DIR, "pr-analysis", "index.json")
SECTION_METADATA = os.path.join(LOCAL_DIR, "section-metadata.json")
USAGE = os.path.join(LOCAL_DIR, "usage.json")
RULE_METADATA = os.path.join(LOCAL_DIR, "rule-metadata.json")
RULE_ALIASES = os.path.join(LOCAL_DIR, "rule-aliases.json")
PROJECT_OVERRIDES = os.path.join(LOCAL_DIR, "project-overrides.json")
DASHBOARD_DIR = os.path.join(HERE, "dashboard")
UNKNOWN_PROJECT = "UNKNOWN"
LEGACY_CONTEXT_WINDOW_SECONDS = 5 * 60
PROJECT_LABEL_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]*/[A-Za-z0-9][A-Za-z0-9_.-]*$")

# Catalog of .local files shown inline on the dashboard Local files view.
LOCAL_FILE_CATALOG = [
    ("Full rules", "RULES.md", "Editable source of truth for developer preferences."),
    ("Compact rules", "RULES.compact.md", "Generated runtime rules file agents read first."),
    ("Rule catalog data", "candidates.json", "Dashboard rule catalog and section payload snapshot."),
    ("Rule metadata", "rule-metadata.json", "Per-rule added dates and provenance."),
    ("Rule aliases", "rule-aliases.json", "Old rule IDs folded into the rule that replaced them."),
    ("Project overrides", "project-overrides.json", "Evidence-backed project labels for ambiguous legacy timestamps."),
    ("Usage data", "usage.json", "Rule application counts, history, and skill-use events."),
    ("Removed rules", "removed.json", "Rules removed from the active set with reasons."),
    ("Developer profile", "profile.json", "Local developer display name and GitHub username."),
    ("Section metadata", "section-metadata.json", "Section origin, evidence PR counts, and sources."),
    ("PR mining index", "pr-analysis/index.json", "Index of PR-mining runs and report paths."),
]

SCRIPT_FILES = [
    "dashboard-state.js",
    "dashboard-utils.js",
    "dashboard-data.js",
    "dashboard-charts.js",
    "dashboard-views.js",
    "dashboard.js",
]


def now_iso():
    """now_iso returns the current local timestamp in ISO-8601 form."""
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def ensure_local_dir():
    """ensure_local_dir creates the ignored local state directory."""
    os.makedirs(LOCAL_DIR, exist_ok=True)


def active_rules_path():
    """active_rules_path returns the developer rules file or the versioned template."""
    return RULES if os.path.exists(RULES) else RULES_EXAMPLE


def init_rules():
    """init_rules creates .local/RULES.md from the versioned example when absent."""
    ensure_local_dir()
    if os.path.exists(RULES):
        print(f"already exists: {RULES}")
        return
    shutil.copyfile(RULES_EXAMPLE, RULES)
    print(f"created: {RULES}")


def github_username_to_dev_name(username):
    """github_username_to_dev_name derives a readable name from a GitHub username."""
    words = re.split(r"[-_.]+", username.strip())
    titled = [word[:1].upper() + word[1:] for word in words if word]
    return " ".join(titled) or username.strip()


def infer_github_username():
    """infer_github_username returns the authenticated GitHub username."""
    result = subprocess.run(
        ["gh", "api", "user", "--jq", ".login"],
        check=False,
        capture_output=True,
        text=True,
    )
    username = result.stdout.strip()
    if result.returncode == 0 and username:
        return username
    message = result.stderr.strip() or result.stdout.strip() or "GitHub username could not be inferred"
    raise RuntimeError(message)


def set_profile(github_username):
    """set_profile writes local developer identity based on a GitHub username."""
    ensure_local_dir()
    username = github_username.strip().lstrip("@")
    profile = {
        "githubUsername": username,
        "devName": github_username_to_dev_name(username),
        "updatedAt": now_iso(),
    }
    write_json(PROFILE, profile)
    print(f"profile: {profile['devName']} (@{profile['githubUsername']})")


def load_profile():
    """load_profile returns local developer identity, or an anonymous default."""
    profile = load_json(PROFILE, {})
    username = (profile.get("githubUsername") or "").strip()
    dev_name = (profile.get("devName") or "").strip()
    if username:
        dev_name = dev_name or github_username_to_dev_name(username)
    else:
        dev_name = dev_name or "Developer"
    return {
        "githubUsername": username,
        "devName": dev_name,
    }


def file_updated_at(path):
    """file_updated_at returns the local mtime for path in ISO-8601 form."""
    return datetime.fromtimestamp(os.path.getmtime(path), timezone.utc).astimezone().isoformat(timespec="seconds")


def parse_rules(path):
    """parse_rules reads a markdown rules file and returns ordered sections.

    Bullets are tracked rules. Prose lines under a heading are section notes:
    context agents should read without it counting as a rule.
    """
    sections = []
    current_h2 = None
    current_h3 = None
    by_name = {}

    def section_name():
        return f"{current_h2} > {current_h3}" if current_h3 else current_h2

    def section_entry():
        name = section_name()
        if name not in by_name:
            entry = {"name": name, "notes": [], "rules": []}
            by_name[name] = entry
            sections.append(entry)
        return by_name[name]

    with open(path, encoding="utf-8") as handle:
        for line in handle:
            h2 = re.match(r"^##\s+(.*)$", line)
            h3 = re.match(r"^###\s+(.*)$", line)
            bullet = re.match(r"^-\s+(.*)$", line)
            if h2:
                current_h2 = h2.group(1).strip()
                current_h3 = None
                continue
            if h3:
                current_h3 = h3.group(1).strip()
                continue
            if not current_h2:
                continue
            if bullet:
                section_entry()["rules"].append(bullet.group(1).strip())
                continue
            note = line.strip()
            if note and note != "---":
                section_entry()["notes"].append(note)
    return sections


def load_json(path, fallback, *, required=False):
    """load_json reads JSON from path, returning fallback if it is absent.

    When required is true and the file exists but is corrupt, raise instead of
    silently falling back.
    """
    if not os.path.exists(path):
        return fallback
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError) as exc:
        if required:
            raise RuntimeError(f"corrupt JSON at {path}: {exc}") from exc
        return fallback


def write_json(path, data):
    """write_json atomically writes JSON to path."""
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    handle, temporary_path = tempfile.mkstemp(prefix=".tmp-", suffix=".json", dir=directory)
    try:
        with os.fdopen(handle, "w", encoding="utf-8") as temporary:
            json.dump(data, temporary, ensure_ascii=False, indent=2)
            temporary.write("\n")
        os.replace(temporary_path, path)
    except Exception:
        try:
            os.unlink(temporary_path)
        except OSError:
            pass
        raise


def load_rule_aliases():
    """load_rule_aliases returns a map of superseded rule IDs to their replacement."""
    data = load_json(RULE_ALIASES, {}, required=True)
    if not isinstance(data, dict):
        return {}
    return {
        str(old): str(new)
        for old, new in data.items()
        if re.match(r"^r-[0-9a-f]{8}$", str(old)) and re.match(r"^r-[0-9a-f]{8}$", str(new))
    }


def resolve_rule_alias(rule_key, aliases):
    """resolve_rule_alias follows an alias chain to the rule that supersedes rule_key."""
    seen = {rule_key}
    resolved = rule_key
    while resolved in aliases and aliases[resolved] not in seen:
        resolved = aliases[resolved]
        seen.add(resolved)
    return resolved


def normalize_usage(existing, project_hints):
    """normalize_usage loads usage counters and history keyed by compact rule ID."""
    aliases = load_rule_aliases()
    usage_by_rule_id = {}
    usage_history_by_rule_id = {}

    for rule_key, value in existing.get("usageByRuleID", {}).items():
        if not re.match(r"^r-[0-9a-f]{8}$", str(rule_key)):
            continue
        resolved = resolve_rule_alias(rule_key, aliases)
        usage_by_rule_id[resolved] = usage_by_rule_id.get(resolved, 0) + int(value or 0)

    for rule_key, events in existing.get("usageHistoryByRuleID", {}).items():
        if not re.match(r"^r-[0-9a-f]{8}$", str(rule_key)):
            continue
        resolved = resolve_rule_alias(rule_key, aliases)
        normalized_events = [
            normalize_tracking_event(event, project_hints)
            for event in events or []
            if isinstance(event, dict)
        ]
        usage_history_by_rule_id.setdefault(resolved, []).extend(normalized_events)

    dated_history = [
        str(event.get("usedAt"))
        for events in usage_history_by_rule_id.values()
        for event in events
        if event.get("usedAt")
    ]
    legacy_anchor = min(dated_history) if dated_history else now_iso()

    for resolved, events in usage_history_by_rule_id.items():
        for event in events:
            if event.get("kind") == "legacy" and not event.get("usedAt"):
                event["usedAt"] = legacy_anchor
        events.sort(key=lambda event: str(event.get("usedAt") or ""))
        usage_by_rule_id[resolved] = max(usage_by_rule_id.get(resolved, 0), len(events))

    for resolved, count in usage_by_rule_id.items():
        events = usage_history_by_rule_id.setdefault(resolved, [])
        missing_history = max(0, count - len(events))
        events[:0] = [
            {
                "kind": "legacy",
                "project": UNKNOWN_PROJECT,
                "query": resolved,
                "reason": "Legacy rule application recorded before detailed usage history.",
                "usedAt": legacy_anchor,
            }
            for _ in range(missing_history)
        ]

    return usage_by_rule_id, usage_history_by_rule_id


def valid_project_label(project):
    """valid_project_label reports whether project uses the required OWNER/REPO format."""
    return bool(PROJECT_LABEL_PATTERN.fullmatch(str(project or "").strip()))


def known_projects(existing, project_override_groups):
    """known_projects returns valid repository labels already present in local evidence."""
    projects = set()
    for events in existing.get("usageHistoryByRuleID", {}).values():
        for event in events or []:
            if isinstance(event, dict) and valid_project_label(event.get("project")):
                projects.add(str(event["project"]).strip())
    for event in existing.get("skillUsage", []):
        if isinstance(event, dict) and valid_project_label(event.get("project")):
            projects.add(str(event["project"]).strip())
    if isinstance(project_override_groups, dict):
        projects.update(
            str(project).strip()
            for project in project_override_groups
            if valid_project_label(project)
        )
    return projects


def contextual_project_for(event, projects):
    """contextual_project_for returns one known repository clearly named by the event."""
    reason = str(event.get("reason") or "")
    full_matches = set()
    repository_matches = set()
    for project in projects:
        owner, repository = project.split("/", 1)
        full_pattern = (
            rf"(?<![A-Za-z0-9_.-]){re.escape(owner)}/{re.escape(repository)}"
            r"(?![A-Za-z0-9_.-])"
        )
        repo_pattern = rf"(?<![A-Za-z0-9_.-]){re.escape(repository)}(?![A-Za-z0-9_.-])"
        if re.search(full_pattern, reason, re.IGNORECASE):
            full_matches.add(project)
        elif re.search(repo_pattern, reason, re.IGNORECASE):
            repository_matches.add(project)
    if full_matches:
        return next(iter(full_matches)) if len(full_matches) == 1 else None
    return next(iter(repository_matches)) if len(repository_matches) == 1 else None


def tracking_event_key(event):
    """tracking_event_key identifies copies of one use across skill and rule history."""
    agent = event.get("agent") if isinstance(event.get("agent"), dict) else {}
    return (
        str(event.get("usedAt") or ""),
        str(event.get("reason") or ""),
        json.dumps(agent, ensure_ascii=False, sort_keys=True),
    )


def build_legacy_project_hints(existing):
    """build_legacy_project_hints infers only repositories supported by local evidence."""
    hints = {}
    conflicts = set()
    project_override_groups = load_json(PROJECT_OVERRIDES, {}, required=True)
    project_overrides = {
        str(used_at): str(project)
        for project, timestamps in project_override_groups.items()
        for used_at in timestamps
        if valid_project_label(project)
    } if isinstance(project_override_groups, dict) else {}
    projects = known_projects(existing, project_override_groups)

    def add_hint(event, project):
        if not project or project == UNKNOWN_PROJECT:
            return
        key = tracking_event_key(event)
        if key in hints and hints[key] != project:
            conflicts.add(key)
            return
        hints[key] = project

    for events in existing.get("usageHistoryByRuleID", {}).values():
        for event in events or []:
            if not isinstance(event, dict):
                continue
            if event.get("kind") == "legacy":
                continue
            recorded_project = str(event.get("project") or "").strip()
            add_hint(
                event,
                (recorded_project if valid_project_label(recorded_project) else None)
                or project_overrides.get(str(event.get("usedAt") or ""))
                or contextual_project_for(event, projects),
            )

    for event in existing.get("skillUsage", []):
        if not isinstance(event, dict):
            continue
        recorded_project = str(event.get("project") or "").strip()
        add_hint(
            event,
            (recorded_project if valid_project_label(recorded_project) else None)
            or project_overrides.get(str(event.get("usedAt") or ""))
            or contextual_project_for(event, projects),
        )

    for key in conflicts:
        hints.pop(key, None)

    dated_events = []
    for event in existing.get("skillUsage", []):
        if not isinstance(event, dict) or not event.get("usedAt"):
            continue
        try:
            used_at = datetime.fromisoformat(str(event["usedAt"]))
        except ValueError:
            continue
        dated_events.append((used_at, event))
    dated_events.sort(key=lambda item: item[0])

    clusters = []
    cluster = []
    previous_at = None
    for used_at, event in dated_events:
        if previous_at is None or (used_at - previous_at).total_seconds() <= LEGACY_CONTEXT_WINDOW_SECONDS:
            cluster.append(event)
        else:
            clusters.append(cluster)
            cluster = [event]
        previous_at = used_at
    if cluster:
        clusters.append(cluster)

    for cluster_events in clusters:
        projects = {
            hints.get(tracking_event_key(event))
            for event in cluster_events
        }
        projects.discard(None)
        if len(projects) != 1:
            continue
        project = next(iter(projects))
        for event in cluster_events:
            add_hint(event, project)

    for key in conflicts:
        hints.pop(key, None)
    return hints


def normalize_tracking_event(event, project_hints):
    """normalize_tracking_event guarantees that a usage event names its project."""
    normalized = dict(event)
    project = str(normalized.get("project") or "").strip()
    normalized["project"] = (
        project_hints.get(tracking_event_key(normalized))
        or (project if valid_project_label(project) else None)
        or UNKNOWN_PROJECT
    )
    return normalized


def normalize_skill_usage(events, project_hints):
    """normalize_skill_usage returns valid skill-use events with project metadata."""
    return [
        normalize_tracking_event(event, project_hints)
        for event in events
        if isinstance(event, dict)
    ]


def load_usage_state():
    """load_usage_state returns usage history from the local usage file."""
    data = load_json(USAGE, {}, required=True)
    return data if isinstance(data, dict) else {}


def load_removed():
    """load_removed returns removed rule history from the local removed file."""
    return load_json(REMOVED, [])


def archived_history_by_rule_id(usage_history_by_rule_id):
    """archived_history_by_rule_id groups events by the rule ID they were recorded against.

    Merged and reworded rules keep their events under the successor's ID, so the
    per-event query is what still identifies the rule that earned each use.
    """
    grouped = {}
    for stored_id, events in usage_history_by_rule_id.items():
        for event in events:
            query = str(event.get("query") or "")
            recorded_id = query if re.match(r"^r-[0-9a-f]{8}$", query) else stored_id
            grouped.setdefault(recorded_id, []).append(event)

    for events in grouped.values():
        events.sort(key=lambda event: str(event.get("usedAt") or ""))
    return grouped


def build_removed(usage_history_by_rule_id):
    """build_removed returns removed rules with the usage history they earned before removal."""
    archived = archived_history_by_rule_id(usage_history_by_rule_id)
    aliases = load_rule_aliases()
    entries = []

    for entry in load_removed():
        if not isinstance(entry, dict):
            continue
        removed_id = rule_id(str(entry.get("text") or ""))
        history = archived.get(removed_id, [])
        details = dict(entry)
        details["ruleID"] = removed_id
        details["usageCount"] = len(history)
        details["history"] = history
        replacement = resolve_rule_alias(removed_id, aliases)
        if replacement != removed_id:
            details["mergedInto"] = replacement
        entries.append(details)

    return entries


def read_local_file_content(path):
    """read_local_file_content loads a local file as JSON when possible, else text."""
    with open(path, encoding="utf-8") as handle:
        raw = handle.read()
    if path.endswith(".json"):
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return raw
    return raw


def slim_pr_report(report):
    """slim_pr_report keeps mining JSON readable in the dashboard without huge PR lists."""
    if not isinstance(report, dict):
        return report

    prs = report.get("prs") if isinstance(report.get("prs"), list) else []
    slim = {key: value for key, value in report.items() if key != "prs"}
    slim["prs"] = {
        "count": len(prs),
        "sample": prs[:3],
    }
    return slim


def load_local_files():
    """load_local_files returns labeled local file previews for the dashboard."""
    items = []
    for label, relative_path, about in LOCAL_FILE_CATALOG:
        path = os.path.join(LOCAL_DIR, relative_path)
        item = {
            "about": about,
            "label": label,
            "path": relative_path,
        }
        if not os.path.exists(path):
            item["error"] = "File not found."
        else:
            content = read_local_file_content(path)
            if relative_path == "candidates.json" and isinstance(content, dict):
                content = {key: value for key, value in content.items() if key != "localFiles"}
            item["content"] = content
        items.append(item)
    return items


def load_pr_mining():
    """load_pr_mining returns local PR-mining history with inline report previews."""
    runs = load_json(PR_MINING_INDEX, [])
    if not isinstance(runs, list):
        return []

    enriched = []
    for run in runs:
        if not isinstance(run, dict):
            continue
        entry = dict(run)
        json_path = str(run.get("json") or "")
        local_name = json_path[7:] if json_path.startswith(".local/") else json_path
        path = os.path.join(LOCAL_DIR, local_name) if local_name else ""
        if path and os.path.exists(path):
            try:
                entry["report"] = slim_pr_report(read_local_file_content(path))
            except OSError as exc:
                entry["reportError"] = str(exc)
        else:
            entry["reportError"] = "Report JSON not found."
        enriched.append(entry)
    return enriched


def load_section_metadata():
    """load_section_metadata returns local evidence metadata by section name."""
    data = load_json(SECTION_METADATA, {})
    return data if isinstance(data, dict) else {}


def first_usage_at(events):
    """first_usage_at returns the oldest timestamp in rule usage events."""
    used_dates = [
        event.get("usedAt")
        for event in events
        if isinstance(event, dict) and event.get("usedAt")
    ]
    return min(used_dates) if used_dates else None


def load_rule_metadata():
    """load_rule_metadata returns local rule metadata by compact rule ID."""
    data = load_json(RULE_METADATA, {}, required=True)
    return data if isinstance(data, dict) else {}


def build_rule_metadata(rule_ids, usage_history_by_rule_id):
    """build_rule_metadata preserves added dates and initializes newly seen rules."""
    existing_metadata = load_rule_metadata()
    seen_at = now_iso()
    metadata = {}

    for rule_id_value in rule_ids.values():
        details = existing_metadata.get(rule_id_value, {})
        added_at = details.get("addedAt")
        added_at_source = details.get("addedAtSource")
        if not added_at:
            added_at = first_usage_at(usage_history_by_rule_id.get(rule_id_value, [])) or seen_at
            added_at_source = "firstUsage" if usage_history_by_rule_id.get(rule_id_value) else "firstSeen"
        metadata[rule_id_value] = {
            "addedAt": added_at,
            "addedAtSource": added_at_source or "recorded",
        }

    return metadata


def apply_section_metadata(sections, metadata):
    """apply_section_metadata attaches local evidence details to parsed sections."""
    for section in sections:
        details = metadata.get(section["name"], {})
        for key in ("origin", "evidencePRs", "source"):
            if details.get(key) is not None:
                section[key] = details[key]


def build_data():
    """build_data assembles local dashboard data from the current rules file."""
    ensure_local_dir()
    rules_path = active_rules_path()
    sections = parse_rules(rules_path)
    apply_section_metadata(sections, load_section_metadata())
    active_count = sum(len(section["rules"]) for section in sections)
    rule_ids = {
        rule: rule_id(rule)
        for section in sections
        for rule in section["rules"]
    }
    usage_state = load_usage_state()
    project_hints = build_legacy_project_hints(usage_state)
    usage_by_rule_id, usage_history_by_rule_id = normalize_usage(usage_state, project_hints)
    rule_metadata = build_rule_metadata(rule_ids, usage_history_by_rule_id)

    return {
        "developer": load_profile(),
        "source": os.path.relpath(rules_path, HERE),
        "generatedAt": now_iso(),
        "rulesUpdatedAt": file_updated_at(rules_path),
        "activeRuleCount": active_count,
        "sectionCount": len(sections),
        "sections": sections,
        "ruleIds": rule_ids,
        "ruleMetadata": rule_metadata,
        "removed": build_removed(usage_history_by_rule_id),
        "usageByRuleID": usage_by_rule_id,
        "usageHistoryByRuleID": usage_history_by_rule_id,
        "skillUsage": normalize_skill_usage(usage_state.get("skillUsage", []), project_hints),
        "prMining": load_pr_mining(),
        "localFiles": load_local_files(),
    }


def write_artifacts(data):
    """write_artifacts persists local data files, compact rules, and dashboard."""
    ensure_local_dir()
    rule_metadata = data.get("ruleMetadata", {})
    usage_data = {
        "usageByRuleID": data.get("usageByRuleID", {}),
        "usageHistoryByRuleID": data.get("usageHistoryByRuleID", {}),
        "skillUsage": data.get("skillUsage", []),
    }
    candidates_data = {
        key: value
        for key, value in data.items()
        if key not in (
            "ruleMetadata",
            "usageByRuleID",
            "usageHistoryByRuleID",
            "skillUsage",
            "removed",
            "prMining",
            "localFiles",
        )
    }
    write_json(RULE_METADATA, rule_metadata)
    write_json(USAGE, usage_data)
    write_json(DATA, candidates_data)
    write_compact_rules(data)
    render_dashboard(data)


def strip_markdown(text):
    """strip_markdown removes lightweight formatting from rule text."""
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"`([^`]+?)`", r"\1", text)
    return text.strip()


def rule_id(rule):
    """rule_id returns a stable compact identifier for the rule's current text."""
    digest = hashlib.sha1(rule.encode("utf-8")).hexdigest()[:8]
    return f"r-{digest}"


def write_compact_rules(data):
    """write_compact_rules writes the short runtime rules file agents read first."""
    developer = data.get("developer", {})
    dev_name = developer.get("devName") or "Developer"
    username = developer.get("githubUsername")
    title = f"# Runtime Developer Preferences: {dev_name}"
    if username:
        title += f" (@{username})"
    lines = [
        title,
        "",
        "Use for normal work. Edit .local/RULES.md only after developer confirmation.",
        "Lines starting with > are section context, not tracked rules.",
        f"Source: {data.get('source', 'unknown')}",
        f"Active rules: {data.get('activeRuleCount', 0)}",
        f"Sections: {data.get('sectionCount', 0)}",
        f"Generated: {data.get('generatedAt', 'unknown')}",
        "",
    ]
    for section in data["sections"]:
        section_name = section["name"].replace(" > ", "/")
        for note in section.get("notes", []):
            lines.append(f"> [{section_name}] {strip_markdown(note)}")
        for rule in section["rules"]:
            lines.append(f"- [{rule_id(rule)}] [{section_name}] {strip_markdown(rule)}")
    lines.append("")
    with open(COMPACT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines))


def split_tracking_args(args, command):
    """split_tracking_args separates rule queries from tracking metadata flags."""
    queries = []
    reason = None
    agent = {}
    project = None
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--reason":
            index += 1
            if index >= len(args):
                print(f'usage: python3 generate.py {command} ... --reason "short reason"')
                sys.exit(1)
            reason = args[index].strip()
        elif arg in ("--agent", "--model"):
            index += 1
            if index >= len(args):
                print(f"usage: python3 generate.py {command} ... {arg} VALUE")
                sys.exit(1)
            value = args[index].strip()
            if value:
                agent[arg.removeprefix("--")] = value
        elif arg == "--project":
            index += 1
            if index >= len(args):
                print(f"usage: python3 generate.py {command} ... --project OWNER/REPO")
                sys.exit(1)
            project = args[index].strip() or None
        else:
            queries.append(arg)
        index += 1

    if not reason:
        print(f'usage: python3 generate.py {command} ... --reason "short reason"')
        sys.exit(1)
    if not valid_project_label(project):
        print(
            "project is required in OWNER/REPO format; infer it from the current Git repository "
            "or ask the developer"
        )
        sys.exit(1)

    return queries, reason, agent, project


def add_tracking_fields(event, reason, agent, project):
    """add_tracking_fields attaches shared tracking metadata to a usage event."""
    event["reason"] = reason
    if agent:
        event["agent"] = agent
    event["project"] = project
    return event


def increment_usage(queries, reason, agent, project):
    """increment_usage records timestamped usage for exactly matched active rules."""
    data = build_data()
    all_rules = [rule for section in data["sections"] for rule in section["rules"]]
    rules_by_id = {rule_id(rule): rule for rule in all_rules}

    aliases = load_rule_aliases()
    matched = []
    for query in queries:
        normalized = resolve_rule_alias(query.lower(), aliases)
        if normalized != query.lower():
            print(f"note: {query} was superseded by {normalized}")
        hits = [rules_by_id[normalized]] if normalized in rules_by_id else [
            rule for rule in all_rules if normalized in rule.lower()
        ]
        if not hits:
            print(f'no active rule matches "{query}" - nothing recorded')
            sys.exit(1)
        if len(hits) > 1:
            print(f'"{query}" is ambiguous ({len(hits)} rules) - nothing recorded. Matches:')
            for rule in hits[:5]:
                print(f"  - {rule[:100]}")
            sys.exit(1)
        matched.append(hits[0])

    used_at = now_iso()
    data["skillUsage"].append(
        add_tracking_fields({"usedAt": used_at, "kind": "rule"}, reason, agent, project)
    )
    for query, rule in zip(queries, matched):
        rule_id_value = rule_id(rule)
        data["usageByRuleID"][rule_id_value] = data["usageByRuleID"].get(rule_id_value, 0) + 1
        data["usageHistoryByRuleID"].setdefault(rule_id_value, []).append(
            add_tracking_fields({"usedAt": used_at, "query": query}, reason, agent, project)
        )
        print(f'used x{data["usageByRuleID"][rule_id_value]}: {rule[:90]} - {reason}')
    write_artifacts(data)


def touch_skill(reason, agent, project):
    """touch_skill records that the skill was used without attributing a rule."""
    data = build_data()
    used_at = now_iso()
    data["skillUsage"].append(
        add_tracking_fields({"usedAt": used_at, "kind": "skill"}, reason, agent, project)
    )
    write_artifacts(data)
    print(f"skill use recorded at {used_at} - {reason}")


def json_for_script(data):
    """json_for_script returns JSON safe to embed inside an HTML script tag."""
    return (
        json.dumps(data, ensure_ascii=False)
        .replace("&", "\\u0026")
        .replace("<", "\\u003c")
        .replace(">", "\\u003e")
        .replace("\u2028", "\\u2028")
        .replace("\u2029", "\\u2029")
    )


def render_dashboard(data):
    """render_dashboard writes the local dashboard HTML that loads versioned assets."""
    payload = json_for_script(data)
    asset_hasher = hashlib.sha1()
    for asset_name in ["dashboard.css", *SCRIPT_FILES]:
        with open(os.path.join(DASHBOARD_DIR, asset_name), "rb") as asset_handle:
            asset_hasher.update(asset_handle.read())
    asset_version = asset_hasher.hexdigest()[:12]
    script_tags = "\n  ".join(
        f'<script src="../dashboard/{script_file}?v={asset_version}"></script>'
        for script_file in SCRIPT_FILES
    )
    template_path = os.path.join(DASHBOARD_DIR, "dashboard.template.html")
    with open(template_path, encoding="utf-8") as template_handle:
        template = template_handle.read()
    with open(DASH, "w", encoding="utf-8") as handle:
        handle.write(
            template
            .replace("__PAYLOAD__", payload)
            .replace("__ASSET_VERSION__", asset_version)
            .replace("__SCRIPT_TAGS__", script_tags)
        )


def main():
    """main dispatches the generator commands."""
    if len(sys.argv) > 1 and sys.argv[1] == "init":
        init_rules()
        return
    if len(sys.argv) > 1 and sys.argv[1] == "profile":
        if len(sys.argv) > 3:
            print("usage: python3 generate.py profile [GITHUB_USER]")
            sys.exit(1)
        try:
            set_profile(sys.argv[2] if len(sys.argv) == 3 else infer_github_username())
        except RuntimeError as exc:
            print(str(exc), file=sys.stderr)
            sys.exit(1)
        write_artifacts(build_data())
        return
    if len(sys.argv) > 1 and sys.argv[1] == "used":
        queries, reason, agent, project = split_tracking_args(sys.argv[2:], "used")
        if not queries:
            print(
                'usage: python3 generate.py used "<rule id or substring>" ... --reason "short reason" '
                "[--agent NAME] [--model VERSION] [--project OWNER/REPO]"
            )
            sys.exit(1)
        increment_usage(queries, reason, agent, project)
        return
    if len(sys.argv) > 1 and sys.argv[1] == "touched":
        queries, reason, agent, project = split_tracking_args(sys.argv[2:], "touched")
        if queries:
            print(
                'usage: python3 generate.py touched --reason "short reason" '
                "[--agent NAME] [--model VERSION] [--project OWNER/REPO]"
            )
            sys.exit(1)
        touch_skill(reason, agent, project)
        return

    data = build_data()
    write_artifacts(data)
    applied = sum(data["usageByRuleID"].values())
    print(
        f"active rules: {data['activeRuleCount']} across {data['sectionCount']} sections; "
        f"removed: {len(data['removed'])}; usage events: {applied}; "
        f"skill uses: {len(data['skillUsage'])}; source: {data['source']}"
    )


if __name__ == "__main__":
    main()
