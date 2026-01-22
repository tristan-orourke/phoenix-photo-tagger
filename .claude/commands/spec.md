# Feature Specification Workflow

Help the user refine their idea into a detailed specification with ADRs and a test plan.

## Process

### 1. Clarify the Idea
Ask questions to understand:
- The goal and motivation (what problem does this solve?)
- Scope and constraints
- User-facing vs internal changes
- Any known requirements or preferences

### 2. Review Previous Decisions
Read `docs/project_notes/decisions.md` to understand:
- Existing architectural decisions that may constrain or guide this feature
- Patterns and conventions already established
- Past decisions that this feature must not contradict

Flag any potential conflicts with previous decisions for discussion.

### 3. Research the Codebase
Explore relevant existing code to understand:
- Current patterns and conventions
- Files/modules that will be affected
- Related functionality that might inform the design
- Potential conflicts or dependencies

### 4. Draft Specification
Write a clear specification including:
- **Problem statement**: What issue or need this addresses
- **Proposed solution**: High-level approach
- **Implementation details**: Key changes by file/module
- **Edge cases**: Boundary conditions to handle
- **Out of scope**: What this intentionally doesn't cover

### 5. Draft ADR
Prepare (but do not yet write) an architectural decision record with:
- Context and problem
- Decision made
- Consequences (positive and negative)
- Alternatives considered

Present the draft ADR as part of the spec for user review.

### 6. Define Test Plan
List specific test cases covering:
- Happy path scenarios
- Edge cases and boundary conditions
- Error handling
- Integration points

### 7. Review and Approve
Present the complete specification (including draft ADR) for user review:
- Walk through each section
- Address questions and concerns
- Iterate on the spec as needed
- **Explicitly ask the user to approve the final spec before proceeding**

Do not update any memory files until the user has approved.

### 8. Commit to Memory (after approval only)
Once the user approves the spec, update the project memory files:

**`docs/project_notes/decisions.md`** - Record the ADR with:
- Date prefix `[YYYY-MM-DD]`
- Context and problem statement
- Decision made and rationale
- Alternatives considered
- Consequences (positive and negative)

**`docs/project_notes/key_facts.md`** - Update if any new essential project information was discovered during research

---

Start by asking the user to describe their idea, then ask clarifying questions before proceeding to research.
