---
argument-hint: [file, directory, or scope to clean]
description: Find and remove dead code, legacy implementations, and over-complexity
---

Use the codebase-cleaner agent to find and remove dead code, legacy implementations, and over-engineered patterns in: $ARGUMENTS

Focus on:
1. **Dead code** - unused functions, variables, imports, files
2. **Legacy code** - deprecated implementations, old feature flags, migration artifacts
3. **Over-complexity** - unnecessary abstractions, over-generalized code

If no arguments provided, ask what area to clean or offer to scan the entire codebase.