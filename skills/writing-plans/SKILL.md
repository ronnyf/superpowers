---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write implementation plans that tell skilled agents *what* to build, not *how* to build it. Plans are briefs — they describe goals, requirements, constraints, and acceptance criteria for each task. The implementing agent brings its own domain expertise, project memory, and creativity to decide the approach.

Assume the implementing agent is skilled but has zero context for the codebase. Document which files to touch, what behavior to achieve, how to verify it, and what constraints to respect. DRY. YAGNI. TDD. Frequent commits.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** This should be run in a dedicated worktree (created by brainstorming skill).

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`

## CRITICAL: No Sample Code in Plans

**NEVER include code snippets, code blocks, or inline code samples in implementation plans.** The implementing agent has full access to the codebase via LSP, Read, Grep, and other tools. It writes code itself based on precise instructions.

Plans specify:
- **What** to change (desired behavior, transformations, additions, removals)
- **Where** to change it (exact file paths and locations)
- **Why** it's ordered this way (dependencies between tasks)
- **How to verify** (acceptance criteria, which tests to run, expected outcomes)
- **Constraints** (invariants, patterns to follow, things to avoid)

Plans do NOT include:
- Code snippets or code blocks
- Inline code examples
- Sample implementations
- Copy-paste ready code

## Bite-Sized Task Granularity

Each task is one focused outcome (2-5 minutes of work). Tasks are described as goals, not procedures — the implementing agent decides how to achieve them using TDD and its own expertise.

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Goal:** [What this task accomplishes — one sentence]

**Files:**
- Create: `exact/path/to/new-file`
- Modify: `exact/path/to/existing-file`
- Test: `exact/path/to/test-file`

**Requirements:**
- [Desired behavior 1]
- [Desired behavior 2]
- [Edge case to handle]

**Constraints:**
- [Architectural constraint, e.g. "must conform to existing Protocol X"]
- [Performance constraint, e.g. "must not block main thread"]
- [Pattern to follow, e.g. "follow the existing pattern in SimilarFile"]

**Acceptance criteria:**
- [How to verify this works — specific test outcomes, build results, observable behavior]
````

## Remember
- Exact file paths always
- Describe transformations precisely in prose (no code)
- Reference relevant docs or existing patterns the agent should study
- Reference relevant skills with @ syntax
- DRY, YAGNI, TDD, frequent commits

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Stay in this session
- Fresh subagent per task + code review

**If Parallel Session chosen:**
- Guide them to open new session in worktree
- **REQUIRED SUB-SKILL:** New session uses superpowers:executing-plans
