---
argument-hint: [file or scope]
description: Review and fix code
---

## Context
Recent changes: !`git diff --stat HEAD~1 2>/dev/null || echo "no recent commits"`

## Task
Use the senior-code-reviewer agent to review: $ARGUMENTS

If no arguments, review unstaged changes from git diff.