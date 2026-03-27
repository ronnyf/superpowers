# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Superpowers is a **skills plugin for coding agents** (Claude Code, Cursor, Codex, OpenCode, Gemini CLI). It provides composable "skills" — structured workflow documents that coding agents invoke automatically to guide software development processes like brainstorming, TDD, debugging, planning, and code review.

This is **not a traditional codebase** — there is no compiled code, no build system, no package manager. The "source code" is primarily Markdown files that define agent behaviors.

## Repository Structure

- `skills/` — Each subdirectory is a skill. The entry point is always `SKILL.md` with YAML frontmatter (`name`, `description`). Skills may include supporting `.md` files referenced from the main skill. May contain symlinks to third-party skills.
- `agents/` — Agent persona definitions (`.md` files) used as subagent prompts by skills like `subagent-driven-development` and `requesting-code-review`.
- `commands/` — Slash command definitions (`.md` files) that map to user-invocable actions like `/brainstorm`, `/write-plan`, `/execute-plan`.
- `hooks/` — Session lifecycle hooks. `hooks.json` defines the hook configuration; `session-start` script runs on session init. `run-hook.cmd` is a polyglot wrapper (bash+cmd) for cross-platform support.
- `third-party/` — Git submodules for externally maintained skills. Symlinked into `skills/` for `superpowers:` namespace discovery.
- `docs/` — Design specs (`docs/superpowers/specs/`), implementation plans (`docs/superpowers/plans/`), and platform-specific setup docs.
- `tests/` — Integration tests that run real Claude Code sessions in headless mode and verify behavior via session transcript (`.jsonl`) parsing.

## Plugin Manifests

The repo targets multiple platforms, each with its own manifest:
- `.claude-plugin/plugin.json` — Claude Code plugin config (registers skills, agents, commands, hooks)
- `.claude-plugin/marketplace.json` — Dev marketplace for local testing
- `.cursor-plugin/plugin.json` — Cursor plugin config
- `.codex/INSTALL.md` — Codex installation instructions
- `.opencode/` — OpenCode plugin support
- `gemini-extension.json` + `GEMINI.md` — Gemini CLI extension

**When bumping versions**, use `scripts/apply-fork-overrides.sh --version X.Y.Z` which updates all manifests at once. Manual editing is no longer needed.

## Branching and Release Workflow

- **main** — single working branch, tracks upstream and holds our fork additions
- **Tags** format: `v5.0.X.Y` on main
- **Remotes:** `internal` = github.pie.apple.com (rfalk/claude-superpowers), `origin` = github.com (obra/superpowers)

Release steps:
1. Commit on main
2. `git push internal main`
3. `git tag v5.0.X.Y` → `git push internal v5.0.X.Y`

## Syncing with Upstream

This is a fork of `origin` (github.com/obra/superpowers). Our fork adds Swift/Xcode agents, skills, and submodules. Manifest overrides (author, source URLs, extra plugins) are managed by scripts so they don't cause merge conflicts.

**Sync workflow:**
```bash
# Preview what's new upstream (no changes made)
scripts/sync-upstream.sh --dry-run

# Merge upstream and re-apply fork overrides
scripts/sync-upstream.sh
```

The sync script: fetches upstream, merges into v5, then runs `apply-fork-overrides.sh` to patch manifests with our fork-specific values from `scripts/fork-config.json`.

**If conflicts occur:** The script stops and tells you which files conflict. Resolve them, commit, then run `scripts/apply-fork-overrides.sh --version <upstream-version>` to re-apply manifest overrides.

**After adding a new fork-specific plugin:** Add its entry to `scripts/fork-config.json` under `marketplace_overrides.extra_plugins`.

**When bumping versions:** Use `scripts/apply-fork-overrides.sh --version X.Y.Z` instead of manually editing each manifest.

## Adding Third-Party Skills

Third-party skills live as git submodules in `third-party/` and are symlinked into `skills/` for discovery:

1. `git submodule add <url> third-party/<name>`
2. `ln -s ../third-party/<name>/<skill-dir> skills/<name>`
3. Add marketplace entry in `.claude-plugin/marketplace.json`
4. Add `superpowers:<name>` to the `skills` array in relevant agents

## Skill Anatomy

Each skill in `skills/<name>/SKILL.md` follows this pattern:
```markdown
---
name: skill-name
description: When to trigger this skill
---
# Title
## Checklist (if rigid workflow)
## Sections with instructions
```

Skills are either **rigid** (must follow exactly, e.g., TDD, debugging) or **flexible** (adapt principles to context). The skill itself indicates which.

## Running Tests

Integration tests execute real Claude Code sessions:

```bash
cd tests/claude-code
./test-subagent-driven-development-integration.sh
```

Requirements:
- Claude Code CLI (`claude`) must be installed
- Must run from the superpowers plugin directory
- Local dev marketplace enabled: `"superpowers@superpowers-dev": true` in `~/.claude/settings.json`
- Tests take 10-30 minutes (real agent sessions with subagents)

Token usage analysis:
```bash
python3 tests/claude-code/analyze-token-usage.py <session-file.jsonl>
```

## Cross-Platform Considerations

- `.gitattributes` enforces LF line endings for all text files (shell scripts, markdown, JSON)
- `hooks/run-hook.cmd` is a polyglot file parsed by both bash and cmd — be careful editing it
- Skills must work across Claude Code, Cursor, Codex, OpenCode, and Gemini CLI

## Key Conventions

- Design docs go in `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
- Implementation plans go in `docs/superpowers/plans/YYYY-MM-DD-<topic>.md`
- New skills should follow the `writing-skills` skill (TDD approach: write pressure tests, establish baseline, write skill, verify compliance)
- The `using-superpowers` skill (`skills/using-superpowers/SKILL.md`) is the entry point — it's loaded into every session and controls skill dispatch
