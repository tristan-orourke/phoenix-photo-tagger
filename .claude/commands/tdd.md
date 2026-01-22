# TDD Workflow

A collaborative test-driven development workflow starting from a specification and implementation plan.

## Prerequisites

This workflow expects:
- A **specification** with a test plan (integration test cases)
- A **detailed implementation plan** listing functions/modules to build

If these don't exist, suggest running `/spec` first to create them.

## Process

### 1. Review Inputs
- Review the spec's test plan (defines integration tests)
- Review the implementation plan (defines units to test)
- Confirm understanding with the user before proceeding

### 2. Review Project Memory
Read the project memory files to inform implementation:

- **`docs/project_notes/decisions.md`**: Understand architectural decisions that must be followed; flag any potential conflicts with the implementation plan
- **`docs/project_notes/bugs.md`**: Learn from past bugs to avoid repeating mistakes; note any patterns or pitfalls relevant to this work
- **`docs/project_notes/key_facts.md`**: Review project conventions, constraints, and essential information

Summarize any relevant findings before proceeding.

### 3. Integration Tests (from spec test plan)
For each test case in the spec's test plan:

a. **Discuss**: Present proposed test implementation, get user feedback
b. **Write tests**: Create the integration test batch (expect them to fail)
c. **Verify red**: Run tests to confirm they fail for the right reasons

### 4. Implementation Cycle
For each function/module in the implementation plan:

a. **Discuss unit tests**: Propose unit test cases for this function, get user input
b. **Write unit tests**: Create the unit test batch (expect fail)
c. **Verify red**: Run unit tests to confirm failure
d. **Implement**: Write the minimal code to pass unit tests
e. **Verify green**: Run unit tests to confirm they pass
f. **Check integration**: Run related integration tests to track progress

### 5. Refactor
After a logical group of functions is complete:

a. Review code for clarity, duplication, and adherence to project patterns
b. Propose refactoring opportunities to the user
c. Apply agreed refactors
d. Re-run all tests to confirm nothing broke

### 6. Completion
When all implementation plan items are done:

a. Run full test suite
b. Verify all integration tests from the spec now pass
c. Summarize what was built and any deviations from the original plan

---

## Commands During Workflow

The user can say:
- **"skip"** - Skip the current test/function and move on
- **"pause"** - Stop and summarize progress so far
- **"tests only"** - Just write tests without discussion for this batch
- **"show plan"** - Display remaining items in the implementation plan

---

## After Completion

Update the project memory files:

**`docs/project_notes/bugs.md`** - Log any bugs discovered during implementation:
- Root cause and solution
- How it was caught (which test, what symptom)
- Lessons learned to prevent similar issues

**`docs/project_notes/key_facts.md`** - Update if:
- New architectural patterns were established
- New conventions were adopted during implementation
- Configuration or environment details changed
- Any other essential project information was learned

**`docs/project_notes/issues.md`** - Add completed work to the work log

---

Start by asking the user to share or point to the spec and implementation plan.
