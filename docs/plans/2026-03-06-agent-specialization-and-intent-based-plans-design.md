# Agent Specialization & Intent-Based Plans Design

## Problem

Superpowers skills and agents are language/platform agnostic. For teams developing primarily in Swift with Xcode, this creates three gaps:

1. **Build verification** — Skills assume CLI-first verification. Xcode builds should be delegated to a specialized build agent, not run ad-hoc.
2. **Code review** — The generic `code-reviewer` agent lacks Swift domain expertise (concurrency, SwiftUI, protocol-oriented design, Apple conventions).
3. **Plans are too prescriptive** — Plans contain sample code and step-by-step commands. This prevents implementation agents from leveraging their domain knowledge, project memory, and creativity.

## Design Principles

- **Skills define process, agents bring domain expertise.** Skills stay generic. Domain knowledge lives in agents.
- **Project memory bridges skills and agents.** Project-level CLAUDE.md tells skills which agents to dispatch (e.g., "use swift-engineer for implementation, xcode-build-reporter for builds").
- **Plans describe intent, not implementation.** Plans say *what* to achieve and *constraints*, never *how*. Implementation agents decide the approach.

## Architecture

The change has two dimensions:

1. **New/adopted agents** — Bring Swift-specialized agents into the repository
2. **Skill updates** — Make skills role-aware and intent-based

```
┌─────────────────────────────────────────────────────────┐
│                    Skills (Process)                       │
│                                                          │
│  writing-plans ──► intent-based task descriptions         │
│  subagent-driven-dev ──► dispatches role-appropriate      │
│  executing-plans ──►      agents per project context      │
│  verification ──► delegates to build agents               │
│  requesting-code-review ──► domain-specific reviewers     │
└──────────────────────┬──────────────────────────────────┘
                       │ dispatches
                       ▼
┌─────────────────────────────────────────────────────────┐
│                   Agents (Domain)                         │
│                                                          │
│  swift-engineer ──► implementation (Swift expertise)      │
│  swift-code-reviewer ──► review (Swift patterns)          │
│  xcode-build-reporter ──► build/test verification         │
│  code-reviewer ──► review (generic, existing)             │
└─────────────────────────────────────────────────────────┘
```

---

## New/Adopted Agents

### `agents/swift-engineer.md` — Adopted from global

Adopted as-is from `~/.claude/agents/swift-engineer.md`. Already project-agnostic.

**Core expertise:**
- Swift 6 strict concurrency (actors, Sendable, structured concurrency, MainActor)
- Type system (parameter packs, opaque types, existentials, conditional conformance, macros)
- Architecture (composition over inheritance, value types, protocol-oriented design)
- Code quality (minimal code, self-documenting, os.log, error handling)
- Testing (Swift Testing framework, not XCTest)
- Build delegation (requests builds from parent agent, never runs xcodebuild directly)

### `agents/xcode-build-reporter.md` — Adopted from global, genericized

Adopted from `~/.claude/agents/xcode-build-reporter.md` with one change: the fallback CLI section is made project-agnostic.

**What stays unchanged:**
- MCP-first approach (XcodeListWindows, BuildProject, GetBuildLog, etc.)
- Step-by-step procedures for building, testing, listing tests
- Test plan discovery with truncation handling and RunAllTests preference
- Structured output format (Status, Errors, Warnings)
- Critical rules (completeness, accuracy, no fixes, no commentary)
- Edge cases (linker errors, build system errors)

**What changes:**
- Fallback xcodebuild commands: Remove hardcoded workspace/scheme/destination. Replace with generic instructions to discover these from the project directory (look for .xcworkspace/.xcodeproj) or ask the parent agent for the build configuration.

### `agents/swift-code-reviewer.md` — New

Swift-specialized code reviewer that extends the base `code-reviewer` framework with Swift domain expertise.

**Inherits from code-reviewer:**
- Plan alignment analysis (compare implementation vs. planned approach)
- Issue categorization (Critical / Important / Suggestions)
- Communication protocol (acknowledge strengths, actionable recommendations)

**Adds Swift-specific review dimensions:**

- **Concurrency safety** — Actor isolation correctness, Sendable conformance, structured vs. unstructured tasks, MainActor usage, data race potential
- **SwiftUI correctness** — State management (@State/@Binding/@Observable/@Environment), view body complexity, performance (avoiding unnecessary recomputation), proper use of task modifiers
- **Protocol-oriented design** — Appropriate use of existentials (`any`) vs. generics (`some`), protocol extensions, associated types, conditional conformance
- **Memory management** — Retain cycles in closures (especially in async contexts), weak/unowned references, value vs. reference type choices
- **API design** — Swift API Design Guidelines compliance, access control (internal/private/public/package), naming conventions
- **Testing patterns** — Swift Testing framework usage (@Test, #expect, #require), async test patterns, proper use of confirmation/withKnownIssue
- **Modern Swift** — Use of modern language features where appropriate (typed throws, parameter ownership, non-copyable types), avoidance of deprecated patterns

**Model:** `inherit`

---

## Skill Changes

### `skills/writing-plans/SKILL.md` — Intent-based plans (major rework)

**Current state:** Plans contain full sample code, exact test implementations, and micro-step TDD instructions (write test → run test → implement → run test → commit).

**New state:** Plans describe *what* to achieve, *where* to work, and *constraints*. Implementation agents decide *how*.

**Changes:**

1. **Remove "Complete code in plan" requirement.** Replace with "Describe the desired behavior, inputs, outputs, and constraints."

2. **Remove sample code blocks from task template.** Tasks become briefs/prompts for implementation agents.

3. **Remove the 5-step TDD micro-steps per task.** The implementer agent follows TDD on its own (via the TDD skill). The plan just specifies the task goal.

4. **Keep "Exact file paths always."** Agents need to know *where* to work.

5. **Keep bite-sized granularity.** Tasks are still small, but described as outcomes not procedures.

6. **New task template:**

```markdown
### Task N: [Component Name]

**Goal:** [What this task accomplishes - one sentence]

**Files:**
- Create: `exact/path/to/file.swift`
- Modify: `exact/path/to/existing.swift`
- Test: `tests/exact/path/to/test.swift`

**Requirements:**
- [Behavior requirement 1]
- [Behavior requirement 2]
- [Edge case to handle]

**Constraints:**
- [Architectural constraint, e.g. "must conform to existing Protocol X"]
- [Performance constraint, e.g. "must not block main thread"]

**Acceptance criteria:**
- [How to verify this works]
```

7. **Update the overview** to reflect the new philosophy: plans are prompts for implementation agents, not step-by-step scripts.

8. **Keep plan header** (Goal, Architecture, Tech Stack) and **execution handoff** (subagent-driven vs. parallel session).

### `skills/subagent-driven-development/SKILL.md` — Role-aware dispatch

**Add "Agent Selection" section** explaining how to choose subagent types:

- Check project context (language, framework, build system)
- For Swift/Xcode projects: use `swift-engineer` for implementation, `swift-code-reviewer` for quality review
- For other projects: use `general-purpose` for implementation, `code-reviewer` for quality review
- Spec reviewer always uses `general-purpose` (checking spec compliance is language-agnostic)

### `skills/subagent-driven-development/implementer-prompt.md` — Role-aware

**Change the template header** from hardcoded `Task tool (general-purpose)` to a note that the controller selects the appropriate subagent type based on project context.

### `skills/subagent-driven-development/code-quality-reviewer-prompt.md` — Domain-specific

**Add note** that the controller can dispatch a domain-specific reviewer (e.g., `swift-code-reviewer`) instead of the generic `code-reviewer` based on project context.

### `skills/executing-plans/SKILL.md` — Agent selection + intent-based execution

**Changes:**
- Add same "Agent Selection" section as subagent-driven-development
- Update "Follow each step exactly" to "Implement each task according to its requirements and acceptance criteria" — the agent uses its own expertise
- Plans are now intent-based, so execution means interpreting requirements, not following literal code steps

### `skills/verification-before-completion/SKILL.md` — Build-agent-aware

**Add note:** For build verification in Xcode projects, dispatch the xcode-build-reporter agent rather than running build commands directly. The evidence is the agent's structured build report.

Core principle unchanged: evidence before claims. Just expand the definition of "running the verification command" to include "dispatching the appropriate verification agent."

### `skills/requesting-code-review/SKILL.md` — Domain-specific reviewer dispatch

**Add note** that the controller should dispatch the appropriate reviewer agent based on project context (e.g., `swift-code-reviewer` for Swift, generic `code-reviewer` as default).

---

## What Stays Unchanged

These skills remain untouched — they're process-level and already generic:

- **brainstorming** — idea refinement process
- **test-driven-development** — RED-GREEN-REFACTOR cycle (project memory handles build agent delegation)
- **systematic-debugging** — root cause investigation process
- **using-git-worktrees** — workspace isolation
- **receiving-code-review** — how to evaluate feedback
- **finishing-a-development-branch** — git workflow
- **using-superpowers** — skill discovery meta-process
- **writing-skills** — skill authoring meta-process
- **dispatching-parallel-agents** — parallel agent coordination

---

## File Change Summary

| File | Action | Size |
|------|--------|------|
| `agents/swift-engineer.md` | Adopt from global (as-is) | Copy |
| `agents/xcode-build-reporter.md` | Adopt from global, genericize fallback | Small edit |
| `agents/swift-code-reviewer.md` | New agent | New file |
| `skills/writing-plans/SKILL.md` | Rework to intent-based tasks | Major rewrite |
| `skills/subagent-driven-development/SKILL.md` | Add agent selection section | Small addition |
| `skills/subagent-driven-development/implementer-prompt.md` | Role-aware subagent type | Small edit |
| `skills/subagent-driven-development/code-quality-reviewer-prompt.md` | Domain-specific reviewer note | Small edit |
| `skills/executing-plans/SKILL.md` | Agent selection + intent-based execution | Medium edit |
| `skills/verification-before-completion/SKILL.md` | Build-agent-aware verification | Small addition |
| `skills/requesting-code-review/SKILL.md` | Domain-specific reviewer dispatch | Small addition |
