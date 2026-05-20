# 66

66 is a Neovim plugin for asking an AI agent about selected code without changing the editor buffer.

## Language

**Ask About Selection**:
A read-only workflow where the user asks a question about visually selected code and receives an AI response.
_Avoid_: visual replace, edit selection

**Selection Context**:
The bounded context sent with an ask, including the selected region, file path, filetype, and current file when small enough.
_Avoid_: whole codebase context

**Response View**:
A configurable Neovim scratch buffer surface that displays the AI response without modifying source files.
_Avoid_: replacement buffer, output file

## Relationships

- An **Ask About Selection** uses exactly one **Selection Context**.
- An **Ask About Selection** produces exactly one **Response View**.

## Example dialogue

> **Dev:** "If I select a function and ask why it fails, will 66 edit the function?"
> **Domain expert:** "No — **Ask About Selection** is read-only and shows the answer in a **Response View**."

## Flagged ambiguities

- "Context" can mean editor context or whole repository context — resolved: **Selection Context** is bounded and does not mean sending the whole codebase by default.
