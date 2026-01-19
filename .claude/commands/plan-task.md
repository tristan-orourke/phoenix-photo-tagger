---
allowed-tools: Read, Edit(.claude/tasks.md), Edit(.claude/plans/*)
description: builds a detailed plan for the next item in a list of tasks.
---


@.claude/tasks.md contains a list of tasks. Each section is a task, possibly including subtasks, and a status. 

1. Find the first section with a status of "READY FOR PLAN". 
2. Think of a detailed plan to complete the task. Ask followup and clarifying questions as necessary. If the original task includes a markdown checklist, items that are already checked off should be ignored.
3. Save the plan to a new file in .claude/plans
4. Edit @.claude/tasks.md to update the status for the task to "PLAN COMPLETE"
