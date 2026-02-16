# Code Review Skill

1. Run: gh pr diff $ARGUMENTS
2. If that fails, run: gh pr view $ARGUMENTS --json files,body
3. Read each changed file for full context
4. Provide review covering: correctness, missing preloads, test coverage, naming conventions
5. Do NOT enter plan mode. Deliver the review directly.
