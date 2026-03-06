# Agent Specialization & Intent-Based Plans Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add specialized agents (swift-engineer, xcode-build-reporter, swift-code-reviewer), make skills role-aware and intent-based.

**Architecture:** Skills remain generic process definitions. New agents encode domain expertise. Skills gain an "Agent Selection" pattern that chooses the right agent based on project context. Plans shift from prescriptive (code samples) to intent-based (what + constraints).

**Tech Stack:** Markdown agent/skill definitions, no code dependencies.

**Design doc:** `docs/plans/2026-03-06-agent-specialization-and-intent-based-plans-design.md`

---

### Task 1: Adopt swift-engineer agent

**Goal:** Bring the global swift-engineer agent into the repository as-is.

**Files:**
- Create: `agents/swift-engineer.md`
- Reference: `~/.claude/agents/swift-engineer.md` (source)

**Requirements:**
- Copy the full content of `~/.claude/agents/swift-engineer.md` into `agents/swift-engineer.md`
- No modifications — the agent is already project-agnostic

**Constraints:**
- Preserve the exact YAML frontmatter (name, description with examples, tools, model, color)
- Preserve all sections: Swift 6 Strict Concurrency, Type System, Architecture, Code Quality, Testing, Software Builds

**Acceptance criteria:**
- File exists at `agents/swift-engineer.md`
- Content is identical to the global version

---

### Task 2: Adopt and genericize xcode-build-reporter agent

**Goal:** Bring the global xcode-build-reporter agent into the repository with project-specific references removed.

**Files:**
- Create: `agents/xcode-build-reporter.md`
- Reference: `~/.claude/agents/xcode-build-reporter.md` (source)

**Requirements:**
- Copy the full content from the global agent
- Replace the hardcoded fallback xcodebuild commands (which reference a specific workspace, scheme, and device) with generic instructions that tell the agent to discover the workspace (.xcworkspace or .xcodeproj in the project directory), scheme (from the workspace), and destination (from available simulators/devices), or to ask the parent agent for the build configuration if discovery fails
- Keep everything else unchanged — MCP tool procedures, output format, critical rules, edge cases are all already generic

**Constraints:**
- Do not remove the fallback section entirely — CLI fallback is still valuable when Xcode MCP is unavailable
- The fallback should explain how to discover build parameters, not hardcode them
- Preserve the YAML frontmatter (name, description with examples, model: haiku, color: blue)

**Acceptance criteria:**
- File exists at `agents/xcode-build-reporter.md`
- No references to any specific workspace name, scheme name, or device name in the file
- Fallback section describes parameter discovery instead of hardcoded values
- All MCP tool procedures, output format, critical rules, and edge cases are preserved from the original

---

### Task 3: Create swift-code-reviewer agent

**Goal:** Create a new Swift-specialized code reviewer that extends the base code-reviewer framework with Swift domain expertise.

**Files:**
- Create: `agents/swift-code-reviewer.md`
- Reference: `agents/code-reviewer.md` (base to extend)

**Requirements:**
- YAML frontmatter: name `swift-code-reviewer`, description with examples showing Swift-specific review scenarios (SwiftUI implementation review, concurrency safety review, protocol-oriented design review), model `inherit`
- System prompt should establish the reviewer as a Senior Swift Code Reviewer
- Inherit the same review framework structure from `code-reviewer.md`: Plan Alignment Analysis, Code Quality Assessment, Architecture and Design Review, Issue Identification (Critical/Important/Suggestions), Communication Protocol
- Add a Swift-specific review checklist section covering:
  - **Concurrency safety**: actor isolation, Sendable conformance, structured vs. unstructured tasks, MainActor usage, data race potential
  - **SwiftUI correctness**: state management (@State/@Binding/@Observable/@Environment), view body complexity, unnecessary recomputation, task modifier usage
  - **Protocol-oriented design**: existentials (`any`) vs. generics (`some`), protocol extensions, associated types, conditional conformance
  - **Memory management**: retain cycles in closures (especially async), weak/unowned references, value vs. reference semantics
  - **API design**: Swift API Design Guidelines compliance, access control, naming conventions
  - **Testing**: Swift Testing framework usage (@Test, #expect, #require), async test patterns
  - **Modern Swift**: typed throws, parameter ownership, non-copyable types, avoidance of deprecated patterns
- The Swift checklist should be additive — the reviewer checks these IN ADDITION TO the generic review dimensions, not instead of

**Constraints:**
- Keep the same output format as `code-reviewer.md` (Strengths, Issues by severity, Recommendations, Assessment)
- Do not duplicate the full generic review instructions — reference or summarize them, then add the Swift layer
- The description examples in frontmatter should follow the same pattern as `code-reviewer.md` (context, user quote, assistant quote, commentary)

**Acceptance criteria:**
- File exists at `agents/swift-code-reviewer.md`
- Contains both generic review dimensions and Swift-specific review checklist
- Uses same issue severity categorization (Critical/Important/Suggestions)
- Description contains Swift-specific triggering examples

---

### Task 4: Rework writing-plans skill to intent-based format

**Goal:** Transform the writing-plans skill from prescriptive (sample code, micro-steps) to intent-based (what + constraints, no code).

**Files:**
- Modify: `skills/writing-plans/SKILL.md`

**Requirements:**
- Update the overview to reflect the new philosophy: plans are prompts/briefs for implementation agents, not step-by-step scripts. Agents have domain expertise, project memory, and creativity — plans tell them what to build, not how.
- Replace the current task structure template (which has 5 TDD micro-steps with code blocks) with the intent-based template from the design doc: Goal, Files, Requirements, Constraints, Acceptance criteria
- Add a prominent "CRITICAL: No Sample Code in Plans" section explaining that plans describe transformations in prose, never include code snippets. The implementing agent writes code itself.
- Update the "Remember" section: replace "Complete code in plan" with "Describe transformations precisely in prose (no code)"
- Keep the plan header (Goal, Architecture, Tech Stack, execution handoff directive)
- Keep the execution handoff section (subagent-driven vs parallel session choice)
- Keep bite-sized granularity principle but reframe: tasks are still small, but described as outcomes (what to achieve) not procedures (what to type)

**Constraints:**
- Preserve the YAML frontmatter unchanged
- Preserve the "Announce at start" instruction
- Preserve the "Context: should be run in a dedicated worktree" note
- Preserve the "Save plans to" path convention
- The skill must remain language/platform agnostic — no Swift-specific content

**Acceptance criteria:**
- No code blocks appear in the task structure template (except for the markdown template itself showing the format)
- The task template contains: Goal, Files, Requirements, Constraints, Acceptance criteria
- The "CRITICAL: No Sample Code" section exists and is prominent
- The execution handoff section is preserved
- The skill reads as a guide for writing intent-based briefs, not prescriptive scripts

---

### Task 5: Add agent selection to subagent-driven-development

**Goal:** Make the subagent-driven-development skill role-aware so it dispatches domain-appropriate agents based on project context.

**Files:**
- Modify: `skills/subagent-driven-development/SKILL.md`
- Modify: `skills/subagent-driven-development/implementer-prompt.md`
- Modify: `skills/subagent-driven-development/code-quality-reviewer-prompt.md`

**Requirements for SKILL.md:**
- Add an "Agent Selection" section (before "The Process") explaining how to choose subagent types based on project context
- The section should cover: check project language/framework/build system, then select appropriate agents for implementation, code quality review, and build verification
- Provide a simple mapping: Swift/Xcode projects use `swift-engineer` for implementation and `swift-code-reviewer` for quality review; other projects use `general-purpose` and `code-reviewer`; spec reviewer always uses `general-purpose` (spec compliance is language-agnostic)
- Note that project memory (CLAUDE.md) may specify which agents to use — check there first

**Requirements for implementer-prompt.md:**
- Change the template header from hardcoded `Task tool (general-purpose)` to a note that the controller selects the appropriate subagent type (e.g., `general-purpose` for most projects, `swift-engineer` for Swift projects)
- The rest of the prompt template stays the same — it's already well-structured

**Requirements for code-quality-reviewer-prompt.md:**
- Add a note that the controller can dispatch a domain-specific reviewer agent (e.g., `swift-code-reviewer`) instead of the generic `superpowers:code-reviewer` based on project context
- Keep the existing template structure

**Constraints:**
- Do not add Swift-specific content to the skill itself — keep it generic with the agent selection as a pattern
- The spec-reviewer-prompt.md should NOT be modified (spec compliance is language-agnostic)
- Preserve all existing content — these are additive changes

**Acceptance criteria:**
- SKILL.md has an "Agent Selection" section with the mapping pattern
- implementer-prompt.md no longer hardcodes `general-purpose`
- code-quality-reviewer-prompt.md mentions domain-specific reviewer option
- No Swift-specific content in the skill body (only in the agent selection mapping as an example)

---

### Task 6: Update executing-plans skill for role-awareness and intent-based plans

**Goal:** Make executing-plans aware of agent selection and update its execution model for intent-based plans.

**Files:**
- Modify: `skills/executing-plans/SKILL.md`

**Requirements:**
- Add the same "Agent Selection" section as subagent-driven-development (consistent pattern across execution skills)
- In Step 2 (Execute Batch), update "Follow each step exactly (plan has bite-sized steps)" to "Implement each task according to its requirements and acceptance criteria" — since plans are now intent-based, the agent uses its own expertise rather than following literal steps
- Add a note that for Xcode projects, build verification should be delegated to the xcode-build-reporter agent

**Constraints:**
- Keep the overall structure (Load/Review, Execute Batch, Report, Continue, Complete Development)
- Keep the "When to Stop and Ask for Help" section unchanged
- Preserve the finishing-a-development-branch integration
- Remain language/platform agnostic — agent selection examples just illustrate the pattern

**Acceptance criteria:**
- Has an "Agent Selection" section
- Step 2 references task requirements/acceptance criteria rather than literal plan steps
- Mentions build agent delegation for Xcode projects as an example

---

### Task 7: Add build-agent-aware verification to verification-before-completion

**Goal:** Expand the verification skill to recognize that verification can be delegated to a specialized agent (e.g., xcode-build-reporter) and the evidence is the agent's structured report.

**Files:**
- Modify: `skills/verification-before-completion/SKILL.md`

**Requirements:**
- Add a "Delegated Verification" subsection (after "The Gate Function") explaining that verification can be performed by dispatching a specialized agent. The agent's structured report is the evidence. Example: dispatch xcode-build-reporter for build verification, read its Build Report as the evidence.
- Update the "Common Failures" table: add a row for delegated builds — "Build succeeds" requires "Build agent report: Status SUCCESS" and is NOT sufficient with "Agent dispatched, assumed success"
- The core Iron Law and Gate Function remain exactly as-is — delegated verification still follows IDENTIFY → RUN → READ → VERIFY → CLAIM, where "RUN" can mean "dispatch verification agent"

**Constraints:**
- Do not weaken the verification standard — delegated verification must still produce concrete evidence
- The addition should be small and surgical — a subsection plus a table row
- Keep the skill language/platform agnostic — xcode-build-reporter is an example, not a mandate

**Acceptance criteria:**
- A "Delegated Verification" subsection exists
- The Common Failures table has a row about agent-delegated builds
- Core Iron Law and Gate Function are unchanged
- The addition makes clear that agent reports ARE the evidence (not "agent was dispatched")

---

### Task 8: Add domain-specific reviewer dispatch to requesting-code-review

**Goal:** Allow requesting-code-review to dispatch domain-specific reviewers instead of always using the generic code-reviewer.

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md`

**Requirements:**
- Add a "Reviewer Selection" note (near the "How to Request" section) explaining that the controller should dispatch the appropriate reviewer agent based on project context
- Provide the same pattern: Swift projects use `swift-code-reviewer`, others use `code-reviewer`
- Note that project memory (CLAUDE.md) may specify which reviewer to use

**Constraints:**
- The code-reviewer.md template file should NOT be modified — it's the generic template that works for any reviewer
- Keep the skill language/platform agnostic — Swift is an example
- Small, surgical addition

**Acceptance criteria:**
- A reviewer selection note exists in the skill
- The note follows the same pattern as agent selection in other skills
- code-reviewer.md template is unchanged

---

### Task 9: Commit all changes

**Goal:** Create a single well-structured commit with all the changes.

**Requirements:**
- Stage all modified and new files
- Write a clear commit message summarizing the changes: new agents (swift-engineer, xcode-build-reporter, swift-code-reviewer), intent-based plans, role-aware skill dispatch
- Reference the design doc in the commit body

**Acceptance criteria:**
- All changes committed
- Commit message accurately describes the scope
