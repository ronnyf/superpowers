---
name: xcode-build-reporting
description: Use when building an Xcode project, running tests, checking for build errors or warnings, or verifying compilation after code changes - covers Xcode MCP tools and xcodebuild CLI fallback
---

# Xcode Build Reporting

## Overview

Build Xcode projects and produce structured reports using **Xcode MCP tools** (preferred) with **xcodebuild CLI** as fallback.

**Core principle:** MCP tools first, CLI fallback only when MCP unavailable. Report everything, fix nothing.

## When to Use

- After making code changes, to verify compilation
- When the user asks to build or check for errors/warnings
- Before claiming a fix compiles or work is complete
- When running or listing tests
- Proactively after implementing features or conformances

## Xcode MCP Tools — Primary Interface

### Quick Reference

| Tool | Purpose | Key Parameters |
|------|---------|----------------|
| `mcp__xcode__XcodeListWindows` | Discover open workspaces and `tabIdentifier` | None |
| `mcp__xcode__BuildProject` | Trigger build, blocks until complete | `tabIdentifier` |
| `mcp__xcode__GetBuildLog` | Read build log by severity | `tabIdentifier`, `severity` (error/warning/remark), `pattern`, `glob` |
| `mcp__xcode__RunAllTests` | Run all tests from active test plan | `tabIdentifier` |
| `mcp__xcode__RunSomeTests` | Run specific tests | `tabIdentifier`, `tests` (JSON array) |
| `mcp__xcode__GetTestList` | List tests from active test plan | `tabIdentifier` |
| `mcp__xcode__XcodeListNavigatorIssues` | List Issue Navigator issues | `tabIdentifier`, `severity`, `pattern`, `glob` |

### Building

1. `XcodeListWindows` → get `tabIdentifier`
2. `BuildProject` with `tabIdentifier` → blocks until done
3. `GetBuildLog` with `severity: "error"` → all errors
4. `GetBuildLog` with `severity: "warning"` → warnings (use `glob` to filter to relevant source files)
5. Optional: `XcodeListNavigatorIssues` for comprehensive UI-visible issues

### Running Tests

1. `XcodeListWindows` → get `tabIdentifier`
2. `GetTestList` → see active test plan, counts, and `fullTestListPath` (response truncates at 100 tests — read `fullTestListPath` for complete list)
3. Prefer `RunAllTests` for all enabled tests. Only use `RunSomeTests` when specific tests are explicitly requested. Do NOT filter `GetTestList` results into `RunSomeTests` — truncation risks missing tests.
4. `GetBuildLog` with `severity: "error"` → check for test failures

### Listing Tests

1. `GetTestList` with `tabIdentifier`
2. Response includes `activeTestPlanName`, `counts` (total/enabled/disabled), and truncated list
3. For complete list: read file at `fullTestListPath` (grep-friendly format with `TEST_TARGET`, `TEST_IDENTIFIER`, `TEST_FILE_PATH`)

## Fallback: xcodebuild CLI

**Only use when Xcode MCP tools are unavailable** (Xcode not open, MCP server not connected, tool calls fail with connection errors).

### Discovery

```bash
# Find workspace/project (prefer .xcworkspace)
ls -d *.xcworkspace *.xcodeproj 2>/dev/null

# List schemes
xcodebuild -list -workspace "<workspace>" 2>&1

# Discover destinations
xcodebuild -showdestinations -workspace "<workspace>" -scheme "<scheme>" 2>&1
```

### Commands

```bash
# Build
xcodebuild build -workspace "<workspace>" -scheme "<scheme>" -destination '<destination>' 2>&1

# Test
xcodebuild test -workspace "<workspace>" -scheme "<scheme>" -destination '<destination>' 2>&1
```

If discovery fails, ask the user for workspace, scheme, and destination.

## Output Format

Always return findings in this exact format:

```
## Build Report

**Status**: SUCCESS | FAILURE

### Errors (N total)
1. `path/to/File.swift:LINE` — Error message here
2. `path/to/OtherFile.swift:LINE` — Error message here
(If no errors: "No errors.")

### Warnings (N total, target-related only)
1. `path/to/File.swift:LINE` — Warning message here
(If no warnings: "No warnings.")
```

## Critical Rules

- **MCP first**: Always try Xcode MCP tools before xcodebuild CLI
- **Completeness**: Never truncate or summarize errors — list every one
- **Accuracy**: Only report what the build output actually contains
- **Relevance for warnings**: Only include warnings from the built target's source files — exclude Apple SDKs, system headers, third-party dependencies
- **No fixes**: Do NOT attempt to fix errors or warnings — build and report only
- **No commentary**: No opinions, suggestions, or next steps — only the structured report
- **Deterministic output**: Use the exact format above so callers can parse reliably

## Edge Cases

| Situation | Handling |
|-----------|----------|
| MCP unavailable | Fall back to xcodebuild CLI, note in report |
| Empty build log | Status: FAILURE, error: "empty build log" |
| Linker errors (no file/line) | `[Linker] — Error message` |
| Build system errors | `[Build System] — Error message` |
