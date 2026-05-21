# 66

66 is a Neovim plugin for asking an AI agent about selected code and making explicit, localized edits from a visual selection.

## Language

**Ask About Selection**:
A read-only workflow where the user asks a question about visually selected code and receives an AI response.
_Avoid_: edit selection, replacement workflow

**Explain Selection**:
A preset **Ask About Selection** where the question is supplied by 66 to explain the visually selected code without opening the prompt buffer.
_Avoid_: separate edit workflow, customizable prompt template

**Edit Selection**:
A write workflow where the user selects code, gives an edit instruction, and allows the AI agent to change the selected block or immediately adjacent lines when the change naturally belongs there.
_Avoid_: whole-file rewrite, broad refactor, unrelated file edits

**Selection Context**:
The bounded context sent with an ask or edit, including the selected region, file path, filetype, and current file when small enough.
_Avoid_: whole codebase context

**Localized Edit Boundary**:
The expected write boundary for an Edit Selection: selected lines first, immediately adjacent lines when appropriate, and wider edits only when required to complete the instruction safely.
_Avoid_: arbitrary project mutation, opportunistic cleanup

**Project**:
The current Neovim working directory used as the boundary for Project Search.
_Avoid_: git root, current file directory

**Response View**:
A configurable Neovim scratch buffer surface that displays the AI response, search fallback output, or edit summary.
_Avoid_: replacement buffer, output file

**Project Search**:
A read-only workflow where the user asks an AI to find relevant code locations across the project and receives a quickfix list.
_Avoid_: edit workflow, replacement workflow, whole-project answer

**Search Question**:
The user-authored prompt for a Project Search. It is sent without Selection Context by default.
_Avoid_: selected code, current file snapshot

**Search Result**:
A navigable quickfix item that points to a relevant file location and explains why it matched the search question.
_Avoid_: prose-only answer, generated patch

**Session History**:
A read-only workflow where the user lists prior opencode sessions for the current Project and opens a transcript in a Response View.
_Avoid_: session mutation, external archive browser

## Relationships

- An **Ask About Selection** uses exactly one **Selection Context**.
- An **Ask About Selection** produces exactly one **Response View**.
- An **Explain Selection** is an **Ask About Selection** preset.
- An **Edit Selection** uses exactly one **Selection Context**.
- An **Edit Selection** is constrained by one **Localized Edit Boundary**.
- An **Edit Selection** produces source-file changes and one **Response View** summary.
- A **Project Search** is bounded by one **Project**.
- A **Project Search** uses exactly one **Search Question**.
- A **Project Search** produces zero or more **Search Results** without modifying source files.
- A **Session History** is bounded by one **Project**.
- A **Session History** opens a selected opencode session as a **Response View**.

## Example dialogue

> **Dev:** "If I select a function and ask why it fails, will 66 edit the function?"
> **Domain expert:** "No — **Ask About Selection** is read-only and shows the answer in a **Response View**. Use **Edit Selection** when you want a localized write."

> **Dev:** "If I select a function and ask 66 to add docs, can it insert comments above the function?"
> **Domain expert:** "Yes — **Edit Selection** may edit immediately adjacent lines when the change naturally belongs next to the selection."

## Flagged ambiguities

- "Context" can mean editor context or whole repository context — resolved: **Selection Context** is bounded and does not mean sending the whole codebase by default.
