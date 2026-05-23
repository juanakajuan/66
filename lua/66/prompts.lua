local M = {}

--- Build the read-only Ask About Selection prompt.
--- @param question string
--- @param context SelectionContext
--- @return string
function M.ask(question, context)
  return table.concat({
    "You are answering a question about a visual selection from a Neovim buffer.",
    "This is read-only. Do not edit files. Answer directly and reference relevant lines when useful.",
    "",
    "Question:",
    question,
    "",
    "File path:",
    context.path ~= "" and context.path or "[No file path]",
    "",
    "Filetype:",
    context.filetype ~= "" and context.filetype or "[No filetype]",
    "",
    string.format("Selected lines: %d-%d", context.start_line, context.end_line),
    "",
    "Selected code:",
    "```" .. (context.filetype or ""),
    context.selected,
    "```",
    "",
    "Current file context:",
    "```" .. (context.filetype or ""),
    context.current_file,
    "```",
  }, "\n")
end

--- Build the read-only Project Search prompt.
--- @param question string
--- @return string
function M.search(question)
  return table.concat({
    "You are performing a read-only Project Search for a Neovim user.",
    "Find code locations in the current project that match the user's Search Question.",
    "Do not edit files. Do not create files. Do not modify buffers.",
    "Return only Search Results. Do not include commentary, markdown, bullets, or code fences.",
    "Each Search Result must use this exact format:",
    "/absolute/path/to/file.ext:line:column,count,notes",
    "line and column are 1-based. count is the number of lines the result covers.",
    "notes must be a single line explaining why the location matched.",
    "If no locations match, return no output.",
    "",
    "Project:",
    vim.fn.getcwd(),
    "",
    "Search Question:",
    question,
  }, "\n")
end

--- Build the read-only Project Tutorial prompt.
--- @param question string
--- @param output_path string Absolute path where the agent must write Tutorial Output.
--- @return string
function M.tutorial(question, output_path)
  return table.concat({
    "You are writing a read-only Project Tutorial for a Neovim user.",
    "Use the current project as the boundary for your investigation.",
    "You may inspect files in the project to answer the Tutorial Question.",
    "Do not edit project files. Do not modify buffers.",
    "Write the final tutorial to the Tutorial Output File and do not print it to stdout.",
    "Do not include tool logs, progress updates, or commentary outside the Tutorial Output File.",
    "The response format must be valid Markdown.",
    "The first line of the response must be the tutorial title.",
    "Write a practical tutorial that helps the user understand the requested topic in this project.",
    "Reference concrete files, functions, commands, or workflows when useful.",
    "",
    "Project:",
    vim.fn.getcwd(),
    "",
    "Tutorial Output File:",
    output_path,
    "",
    "Tutorial Question:",
    question,
  }, "\n")
end

--- Build the Edit Selection prompt.
--- @param instruction string
--- @param context SelectionContext
--- @return string
function M.edit(instruction, context)
  return table.concat({
    "You are editing the selected code block for a Neovim user.",
    "The selected code block is the edit target. Localize changes to that selection.",
    "You may read the whole file or explore the codebase for context.",
    "You may edit the selected lines and immediately adjacent lines when the requested change naturally belongs "
      .. "next to the selection, such as adding documentation, annotations, imports, or small setup/cleanup code.",
    "Do not edit elsewhere unless the request cannot be completed safely without doing so.",
    "If you must edit elsewhere, keep it minimal and explain why in your summary.",
    "Do not make unrelated refactors.",
    "After editing, summarize the localized change and any edits made outside the selection.",
    "",
    "Instruction:",
    instruction,
    "",
    "File path:",
    context.path ~= "" and context.path or "[No file path]",
    "",
    "Filetype:",
    context.filetype ~= "" and context.filetype or "[No filetype]",
    "",
    string.format("Selected lines: %d-%d", context.start_line, context.end_line),
    "",
    "Selected code:",
    "```" .. (context.filetype or ""),
    context.selected,
    "```",
    "",
    "Nearby file context:",
    "```" .. (context.filetype or ""),
    context.edit_context,
    "```",
  }, "\n")
end

return M
