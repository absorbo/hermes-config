#!/usr/bin/env python3
"""Policy-driven Hermes pre_tool_call guard.

Scope: mechanical enforcement of documented guardrail classes only.
No task-scope decisions. No incident-by-incident firewall sprawl.
"""
from __future__ import annotations

import fnmatch
import json
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

POLICY_PATH = Path("/Users/absorbo/.hermes/gates/policy.yaml")
STAMP_ROOT = Path("/tmp/hermes-pretool-guard")


def block(message: str) -> None:
    print(json.dumps({"action": "block", "message": message}))
    raise SystemExit(0)


def allow() -> None:
    print(json.dumps({"action": "allow"}))
    raise SystemExit(0)


def parse_policy(path: Path) -> dict[str, Any]:
    """Tiny YAML subset parser for this policy file: maps + string lists."""
    policy: dict[str, Any] = {}
    stack: list[tuple[int, Any]] = [(-1, policy)]
    last_key_at_indent: dict[int, str] = {}
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        text = line.strip()
        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1]
        if text.startswith("- "):
            value = text[2:].strip()
            if not isinstance(parent, list):
                continue
            parent.append(value)
            continue
        if ":" in text:
            key, value = text.split(":", 1)
            key = key.strip()
            value = value.strip()
            if value == "":
                container: Any = {}
                if isinstance(parent, dict):
                    parent[key] = container
                    last_key_at_indent[indent] = key
                stack.append((indent, container))
            else:
                if value.lower() == "true":
                    parsed: Any = True
                elif value.lower() == "false":
                    parsed = False
                else:
                    parsed = value
                if isinstance(parent, dict):
                    parent[key] = parsed
        # Convert empty dict to list when next child is list.
        if stack and isinstance(stack[-1][1], dict):
            pass
    # Second pass with PyYAML if available; keeps policy maintainable when installed.
    try:
        import yaml  # type: ignore
        loaded = yaml.safe_load(path.read_text())
        if isinstance(loaded, dict):
            return loaded
    except Exception:
        pass
    # Manual parser cannot infer lists under keys in all cases; use explicit fallback for current policy.
    return {
        "paths": {
            "home": "/Users/absorbo",
            "hermes": "/Users/absorbo/.hermes",
            "vault": "/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian",
            "mirror": "/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian/05 - AI/99 - Hermes",
        },
        "read_before_act": {
            "required": ["/Users/absorbo/.hermes/SOUL.md", "/Users/absorbo/.hermes/prefill.txt"],
            "require_state_read": True,
        },
        "repository_order": {
            "primary_repo": "/Users/absorbo/Library/Mobile Documents/iCloud~md~obsidian/Documents/Obsidian",
            "secondary_repo": "/Users/absorbo/.hermes",
            "require_primary_pushed_before_secondary_push": True,
            "require_mirror_sync_before_secondary_commit": True,
        },
        "runtime_artifacts": ["state.db*", "state-snapshots/", "pastes/", "node_modules/"],
        "security_controls": {"require_explicit_approval": ["github_push_protection_bypass", "git_force_push"]},
        "protected_actions": {
            "always_block": ["email_send", "email_delete", "git_init_in_hermes"],
            "require_explicit_instruction": ["protected_config_write"],
        },
    }


POLICY = parse_policy(POLICY_PATH)
HERMES = Path(POLICY["paths"]["hermes"])
VAULT = Path(POLICY["paths"]["vault"])
MIRROR = Path(POLICY["paths"]["mirror"])


def payload() -> dict[str, Any]:
    try:
        return json.load(sys.stdin)
    except Exception:
        allow()
        raise SystemExit(0)


def tool_name(p: dict[str, Any]) -> str:
    return str(p.get("tool_name") or "")


def tool_input(p: dict[str, Any]) -> dict[str, Any]:
    ti = p.get("tool_input") or {}
    return ti if isinstance(ti, dict) else {}


def command(p: dict[str, Any]) -> str:
    return str(tool_input(p).get("command") or "")


def input_path(p: dict[str, Any]) -> str:
    ti = tool_input(p)
    return str(ti.get("path") or ti.get("file_path") or "")


def cwd_path(p: dict[str, Any]) -> Path:
    try:
        return Path(str(p.get("cwd") or "/Users/absorbo")).expanduser().resolve()
    except Exception:
        return Path(str(p.get("cwd") or "/Users/absorbo")).expanduser()


def session_dir(p: dict[str, Any]) -> Path:
    sid = p.get("session_id") or p.get("extra", {}).get("parent_session_id") or "no-session"
    safe = re.sub(r"[^A-Za-z0-9_.-]", "_", str(sid))[:120]
    d = STAMP_ROOT / safe
    d.mkdir(parents=True, exist_ok=True)
    return d


def stamp_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", name)


def stamp(d: Path, name: str) -> None:
    (d / stamp_name(name)).write_text(str(int(time.time())))


def stamped(d: Path, name: str, max_age: int | None = None) -> bool:
    p = d / stamp_name(name)
    if not p.exists():
        return False
    return max_age is None or time.time() - p.stat().st_mtime <= max_age


def under(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except Exception:
        return False


def command_context(c: str, default: Path) -> Path:
    m = re.search(r"(?:^|[;&|]\s*)cd\s+([^;&|]+)", c)
    if not m:
        return default
    raw = m.group(1).strip().strip('"\'').replace("~", "/Users/absorbo", 1)
    try:
        return Path(raw).expanduser().resolve()
    except Exception:
        return Path(raw).expanduser()


def git_output(repo: Path, args: list[str], timeout: int = 8) -> str | None:
    try:
        r = subprocess.run(["git", *args], cwd=str(repo), text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None


def staged(repo: Path) -> list[str]:
    out = git_output(repo, ["diff", "--cached", "--name-only"])
    return [] if out is None else [x for x in out.splitlines() if x]


def remote_head(repo: Path) -> str | None:
    out = git_output(repo, ["ls-remote", "origin", "refs/heads/main"], timeout=12)
    return out.split()[0] if out else None


def local_head(repo: Path) -> str | None:
    return git_output(repo, ["rev-parse", "HEAD"])


def runtime_matches(paths: list[str]) -> list[str]:
    patterns = POLICY.get("runtime_artifacts", [])
    bad: list[str] = []
    for p in paths:
        norm = p.strip("/")
        for pat in patterns:
            clean = str(pat).strip()
            if clean.endswith("/"):
                if f"/{clean.strip('/')}" in f"/{norm}" or norm.startswith(clean.strip("/")):
                    bad.append(p)
                    break
            elif fnmatch.fnmatch(Path(norm).name, clean) or fnmatch.fnmatch(norm, clean):
                bad.append(p)
                break
    return bad


def record_reads(p: dict[str, Any], d: Path) -> None:
    t = tool_name(p)
    hay = input_path(p) + "\n" + command(p)
    for required in POLICY["read_before_act"]["required"]:
        if required in hay or Path(required).name in hay:
            stamp(d, "read:" + required)
    if t == "skill_view":
        stamp(d, "read:skill")
    if t in {"read_file", "search_files"}:
        stamp(d, "read:state")
    if t == "terminal" and re.search(r"\b(git status|git diff|git log|git ls-remote|find |grep |rg |sed -n|wc |stat |pwd|which |date)\b", command(p)):
        stamp(d, "read:state")
    if t in {"read_file", "search_files", "skill_view"}:
        allow()


def substantive(p: dict[str, Any]) -> bool:
    t = tool_name(p)
    if t in {"patch", "write_file", "execute_code"}:
        return True
    if t != "terminal":
        return False
    c = command(p)
    readish = re.search(r"\b(git status|git diff|git log|git ls-remote|find |grep |rg |sed -n|wc |stat |pwd|which |date)\b", c)
    writes = re.search(r"\b(rm|mv|cp|rsync|git add|git commit|git push|git init|chmod|chown|mkdir|touch)\b|write_text|open\(.*['\"]w", c)
    return not (readish and not writes)


def enforce_read_before_act(p: dict[str, Any], d: Path) -> None:
    if not substantive(p):
        return
    missing: list[str] = []
    for required in POLICY["read_before_act"]["required"]:
        if not stamped(d, "read:" + required):
            missing.append(required)
    if POLICY["read_before_act"].get("require_state_read") and not stamped(d, "read:state"):
        missing.append("relevant current files/config/state")
    if missing:
        block("Blocked: read-before-act gate failed. Read " + ", ".join(missing) + " first.")


def classify_and_enforce(p: dict[str, Any], d: Path) -> None:
    t = tool_name(p)
    c = command(p)
    target = input_path(p)
    hay = f"{target}\n{c}"
    ctx = command_context(c, cwd_path(p))
    in_hermes = under(ctx, HERMES) or str(HERMES) in hay or "~/.hermes" in hay
    in_vault = under(ctx, VAULT) or str(VAULT) in hay

    # Protected-action class.
    if re.search(r"\b(email|mail|gmail|himalaya|m365|graph)\b", c.lower()) and re.search(r"\b(send|delete|trash|purge|expunge|remove)\b", c.lower()) and "draft" not in c.lower():
        block("Blocked: protected action class=email_send_or_delete. Draft only.")
    if in_hermes and re.search(r"\bgit\s+init\b", c):
        block("Blocked: protected action class=git_init_in_hermes.")
    if t in {"patch", "write_file"} and (str(HERMES / "config.yaml") in hay or str(HERMES / "SOUL.md") in hay or str(HERMES / "prefill.txt") in hay or re.search(r"/Users/absorbo/\.hermes/profiles/[^/]+/config\.yaml", hay)):
        block("Blocked: protected action class=protected_config_write. Use explicit audited terminal edit with backup.")

    # Security-control class.
    if re.search(r"secret-scanning/push-protection-bypasses|unblock-secret", c):
        if "APPROVED_PUSH_PROTECTION_BYPASS" not in c:
            block("Blocked: security-control class=github_push_protection_bypass requires explicit approval.")
    if re.search(r"\bgit\s+push\b.*(--force|-f)|\bgit\s+push\b.*\+", c):
        if "APPROVED_FORCE_PUSH" not in c:
            block("Blocked: security-control class=git_force_push requires explicit approval.")

    # Repository-order + runtime-artifact classes.
    if in_hermes and re.search(r"\bgit\s+add\s+(-A|--all|\.)\b", c):
        block("Blocked: repository-order class forbids blind staging in ~/.hermes; stage explicit paths.")
    if in_hermes and re.search(r"\bgit\s+commit\b", c):
        bad = runtime_matches(staged(HERMES))
        if bad:
            block("Blocked: runtime-artifact class in Hermes commit: " + ", ".join(bad))
        if POLICY["repository_order"].get("require_mirror_sync_before_secondary_commit") and not (stamped(d, "mirror_synced", 3600) and stamped(d, "mirror_cleaned", 3600)):
            block("Blocked: repository-order class requires fresh mirror sync and cleanup before Hermes commit.")
    if in_vault and re.search(r"\bgit\s+commit\b", c):
        bad = [p for p in runtime_matches(staged(VAULT)) if p.startswith("05 - AI/99 - Hermes/")]
        if bad:
            block("Blocked: runtime-artifact class in vault mirror commit: " + ", ".join(bad))
    if in_hermes and re.search(r"\bgit\s+push\b", c):
        if POLICY["repository_order"].get("require_primary_pushed_before_secondary_push"):
            if not local_head(VAULT) or local_head(VAULT) != remote_head(VAULT):
                block("Blocked: repository-order class requires clawbot-vault pushed before hermes-config push.")


def record_workflow_stamps(p: dict[str, Any], d: Path) -> None:
    c = command(p)
    if "rsync" in c and str(HERMES) in c and str(MIRROR) in c:
        stamp(d, "mirror_synced")
    if str(MIRROR) in c and re.search(r"state\.db|state-snapshots|node_modules|pastes", c) and re.search(r"\brm\b|find .* -exec rm", c):
        stamp(d, "mirror_cleaned")


def main() -> None:
    p = payload()
    d = session_dir(p)
    record_reads(p, d)
    enforce_read_before_act(p, d)
    classify_and_enforce(p, d)
    record_workflow_stamps(p, d)
    allow()


if __name__ == "__main__":
    main()
