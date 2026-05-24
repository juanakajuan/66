local test_utils = require("tests.test_utils")

local function patch_selection(start_line, start_col, end_line, end_col, mode)
  test_utils.patch(vim.fn, "mode", function()
    return "n"
  end)
  test_utils.patch(vim.fn, "visualmode", function()
    return mode or "v"
  end)
  test_utils.patch(vim.fn, "getpos", function(mark)
    if mark == "'<" then
      return { 0, start_line, start_col, 0 }
    end
    if mark == "'>" then
      return { 0, end_line, end_col, 0 }
    end
    error("unexpected mark: " .. mark)
  end)
end

local function joined(lines)
  return table.concat(lines, "\n")
end

describe("66", function()
  after_each(function()
    test_utils.cleanup()
    require("66.config").setup()
  end)

  it("registers user commands", function()
    require("66").setup({
      ask_keymap = false,
      explain_keymap = false,
      search_keymap = false,
      history_keymap = false,
      edit_keymap = false,
      cancel_keymap = false,
    })

    assert.equals(2, vim.fn.exists(":Ask66"))
    assert.equals(2, vim.fn.exists(":Explain66"))
    assert.equals(2, vim.fn.exists(":Search66"))
    assert.equals(2, vim.fn.exists(":History66"))
    assert.equals(2, vim.fn.exists(":Edit66"))
    assert.equals(2, vim.fn.exists(":Cancel66"))
  end)

  describe("Selection Context", function()
    it("captures a charwise selection with line-numbered file context", function()
      local context = require("66.context")
      local bufnr = test_utils.create_buffer({
        "alpha",
        "local value = 1",
        "return value",
      }, "lua")
      vim.api.nvim_buf_set_name(bufnr, "/tmp/selection.lua")
      patch_selection(2, 1, 2, 5)

      local selection = context.selection()

      assert.equals("/tmp/selection.lua", selection.path)
      assert.equals("lua", selection.filetype)
      assert.equals(2, selection.start_line)
      assert.equals(2, selection.end_line)
      assert.equals("2: local", selection.selected)
      assert.equals("1: alpha\n2: local value = 1\n3: return value", selection.current_file)
      assert.equals(selection.current_file, selection.edit_context)
    end)

    it("normalizes reversed linewise selections", function()
      local context = require("66.context")
      test_utils.create_buffer({
        "one",
        "two",
        "three",
        "four",
      }, "lua")
      patch_selection(4, 1, 2, 1, "V")

      local selection = context.selection()

      assert.equals(2, selection.start_line)
      assert.equals(4, selection.end_line)
      assert.equals("2: two\n3: three\n4: four", selection.selected)
    end)

    it("omits oversized current files and bounds edit context", function()
      require("66.config").setup({
        max_file_lines = 3,
        edit_context_lines = 3,
      })
      local context = require("66.context")
      test_utils.create_buffer({
        "one",
        "two",
        "three",
        "four",
        "five",
      }, "lua")
      patch_selection(3, 1, 3, 5)

      local selection = context.selection()

      assert.equals(
        "Current file omitted because it has 5 lines, over the 3 line limit.",
        selection.current_file
      )
      assert.equals("2: two\n3: three\n4: four", selection.edit_context)
    end)

    it("errors when there is no visual selection", function()
      local context = require("66.context")
      test_utils.create_buffer({ "local value = 1" }, "lua")
      patch_selection(0, 0, 0, 0)

      local ok, err = pcall(context.selection)

      assert.is_false(ok)
      assert.equals("missing visual selection", err)
    end)
  end)

  describe("Ask Selection", function()
    it("shows Asking status until response completes, then opens response", function()
      local ask = require("66.ask")
      local opencode = require("66.opencode")
      local ui = require("66.ui")
      local bufnr = test_utils.create_buffer({
        "local value = old()",
        "return value",
      }, "lua")
      local complete
      local response

      patch_selection(1, 1, 1, 1, "V")
      test_utils.patch(ui, "capture_prompt", function(title, name, label, on_submit)
        assert.equals(" 66 ask ", title)
        assert.equals("66 ask", name)
        assert.equals("Ask66", label)
        on_submit("What does this do?")
      end)
      test_utils.patch(opencode, "run", function(_, on_complete)
        complete = on_complete
      end)
      test_utils.patch(ui, "open_scratch_response", function(name, lines, filetype)
        response = { name = name, lines = lines, filetype = filetype }
      end)

      ask.run()

      local namespace = vim.api.nvim_get_namespaces()["66_ask_status"]
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
      assert.equals(2, #marks)
      assert.equals("⣾ Asking", marks[1][4].virt_lines[1][1][1])
      assert.is_nil(response)

      complete({ code = 0 }, "The answer")

      marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
      assert.equals(0, #marks)
      assert.equals("66 response", response.name)
      assert.equals("markdown", response.filetype)
      assert.same({ "The answer" }, response.lines)
    end)
  end)

  describe("OpenCode", function()
    it("requests JSON output from opencode commands", function()
      local opencode = require("66.opencode")

      local command = opencode.command("question", "title")

      assert.same({
        "opencode",
        "run",
        "--format",
        "json",
        "--agent",
        "build",
        "-m",
        "openai/gpt-5.5",
        "--variant",
        "low",
        "--title",
        "title",
        "question",
      }, command)
    end)

    it("returns final answer text from opencode part events", function()
      local opencode = require("66.opencode")
      local completed_text

      test_utils.patch(vim, "system", function(_, opts, on_complete)
        opts.stdout(
          nil,
          joined({
            vim.json.encode({
              type = "text",
              part = {
                type = "text",
                text = "I’ll inspect nearby modules first.",
                metadata = { openai = { phase = "commentary" } },
              },
            }),
            vim.json.encode({
              type = "tool_use",
              part = { type = "tool", tool = "grep", state = { output = "Found 19 matches" } },
            }),
            vim.json.encode({
              type = "text",
              part = {
                type = "text",
                text = "This is the actual answer.",
                metadata = { openai = { phase = "final_answer" } },
              },
            }),
          })
        )
        on_complete({ code = 0 })
      end)

      opencode.run({ "opencode", "run", "question" }, function(_, text)
        completed_text = text
      end)
      test_utils.next_frame()

      assert.equals("This is the actual answer.", completed_text)
    end)

    it("falls back to stripping formatted progress transcript", function()
      local opencode = require("66.opencode")
      local completed_text

      test_utils.patch(vim, "system", function(_, opts, on_complete)
        opts.stdout(
          nil,
          joined({
            "\27[0m→  \27[0mSkill \"vim\"",
            "I’ll inspect nearby modules first.",
            "\27[0m✱  \27[0mGlob \"lua/66/*.lua\" \27[90m in . · 11 matches \27[0m",
            "\27[0m→  \27[0mRead lua/66/opencode.lua \27[90m [offset=1, limit=220] \27[0m",
            "This is the actual answer.",
          })
        )
        on_complete({ code = 0 })
      end)

      opencode.run({ "opencode", "run", "question" }, function(_, text)
        completed_text = text
      end)
      test_utils.next_frame()

      assert.equals("This is the actual answer.", completed_text)
    end)

    it("cancels the newest active request with TERM", function()
      local opencode = require("66.opencode")
      local completions = {}
      local killed = {}
      local cancel_count = 0
      local notifications = {}
      local states = {}

      test_utils.patch(vim, "system", function(_, _, on_complete)
        local index = #completions + 1
        completions[index] = on_complete
        return {
          kill = function(_, signal)
            killed[index] = signal
          end,
        }
      end)
      test_utils.patch(vim, "notify", function(message, level)
        table.insert(notifications, { message = message, level = level })
      end)

      opencode.run({ "opencode", "run", "first" }, function(_, _, state)
        states[1] = state
      end)
      opencode.run({ "opencode", "run", "second" }, function(_, _, state)
        states[2] = state
      end, {
        on_cancel = function()
          cancel_count = cancel_count + 1
        end,
      })

      opencode.cancel_active()
      completions[2]({ code = 143 })
      test_utils.next_frame()

      assert.is_nil(killed[1])
      assert.equals(vim.uv.constants.SIGTERM, killed[2])
      assert.equals(1, cancel_count)
      assert.same({ canceled = true }, states[2])
      assert.equals("Canceled 66 request", notifications[1].message)
      assert.equals(vim.log.levels.INFO, notifications[1].level)

      completions[1]({ code = 0 })
      test_utils.next_frame()
    end)

    it("notifies when there is no active request to cancel", function()
      local cancel = require("66.cancel")
      local notification

      test_utils.patch(vim, "notify", function(message, level)
        notification = { message = message, level = level }
      end)

      cancel.run()

      assert.equals("No active 66 request to cancel", notification.message)
      assert.equals(vim.log.levels.INFO, notification.level)
    end)
  end)

  describe("Project Search", function()
    it("parses Search Results into quickfix and opens it", function()
      local search = require("66.search")
      local opencode = require("66.opencode")
      local ui = require("66.ui")
      local stopped = false
      local opened = false

      test_utils.patch(ui, "start_status_throbber", function(label)
        assert.equals("Searching", label)
        return function()
          stopped = true
        end
      end)
      test_utils.patch(opencode, "run", function(_, on_complete)
        on_complete(
          { code = 0 },
          joined({
            "/tmp/alpha.lua:12:3,2,first match",
            "not a result",
            "/tmp/beta.lua:4:1,1,second match",
          })
        )
      end)
      test_utils.patch(vim, "cmd", function(command)
        assert.equals("copen", command)
        opened = true
      end)

      search.run("find matches")

      local qf = vim.fn.getqflist({ title = 1, items = 1 })
      local first = qf.items[1]
      local second = qf.items[2]

      assert.is_true(stopped)
      assert.is_true(opened)
      assert.equals("66 Search: find matches", qf.title)
      assert.equals(2, #qf.items)
      assert.equals("/tmp/alpha.lua", first.filename or vim.fn.bufname(first.bufnr))
      assert.equals(12, first.lnum)
      assert.equals(3, first.col)
      assert.equals(13, first.end_lnum)
      assert.equals("first match", first.text)
      assert.equals("/tmp/beta.lua", second.filename or vim.fn.bufname(second.bufnr))
      assert.equals(4, second.lnum)
      assert.equals(1, second.col)
      assert.equals(4, second.end_lnum)
      assert.equals("second match", second.text)
    end)

    it("opens raw output when Search Results are unparseable", function()
      local search = require("66.search")
      local opencode = require("66.opencode")
      local ui = require("66.ui")
      local response

      test_utils.patch(ui, "start_status_throbber", function()
        return function() end
      end)
      test_utils.patch(opencode, "run", function(_, on_complete)
        on_complete({ code = 0 }, "plain prose instead of Search Results")
      end)
      test_utils.patch(ui, "open_scratch_response", function(name, lines, filetype)
        response = { name = name, lines = lines, filetype = filetype }
      end)
      test_utils.patch(vim, "cmd", function()
        error("quickfix should not open for unparseable output")
      end)

      search.run("where is auth")

      assert.equals(0, #vim.fn.getqflist())
      assert.equals("66 search output", response.name)
      assert.equals("markdown", response.filetype)
      assert.equals("No parseable Search Results.", response.lines[1])
      assert.equals("66 Search: where is auth", response.lines[3])
      assert.equals("plain prose instead of Search Results", response.lines[5])
    end)

    it("opens an error response when opencode fails", function()
      local search = require("66.search")
      local opencode = require("66.opencode")
      local ui = require("66.ui")
      local response

      test_utils.patch(ui, "start_status_throbber", function()
        return function() end
      end)
      test_utils.patch(opencode, "run", function(_, on_complete)
        on_complete({ code = 7 }, "boom")
      end)
      test_utils.patch(ui, "open_scratch_response", function(name, lines, filetype)
        response = { name = name, lines = lines, filetype = filetype }
      end)
      test_utils.patch(vim, "cmd", function()
        error("quickfix should not open after opencode failure")
      end)

      search.run("find bug")

      assert.equals(0, #vim.fn.getqflist())
      assert.equals("66 search error", response.name)
      assert.equals("markdown", response.filetype)
      assert.equals("opencode exited with code 7", response.lines[1])
      assert.equals("boom", response.lines[3])
    end)
  end)

  describe("Edit Selection", function()
    it("runs opencode with the selected context and clears status", function()
      local edit = require("66.edit")
      local opencode = require("66.opencode")
      local ui = require("66.ui")
      local bufnr = test_utils.create_buffer({
        "local value = old()",
        "return value",
      }, "lua")
      local captured_command

      patch_selection(1, 1, 1, 1, "V")
      test_utils.patch(ui, "capture_prompt", function(title, name, label, on_submit)
        assert.equals(" 66 edit ", title)
        assert.equals("66 edit", name)
        assert.equals("Edit66", label)
        on_submit("Use new_value()")
      end)
      test_utils.patch(opencode, "run", function(command, on_complete)
        captured_command = command
        on_complete({ code = 0 }, "changed")
      end)

      edit.run()

      local prompt = captured_command[#captured_command]
      local namespace = vim.api.nvim_get_namespaces()["66_edit_status"]
      local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})

      assert.truthy(captured_command)
      assert.is_true(prompt:find("Instruction:\nUse new_value()", 1, true) ~= nil)
      assert.is_true(prompt:find("Selected lines: 1-1", 1, true) ~= nil)
      assert.is_true(prompt:find("1: local value = old()", 1, true) ~= nil)
      assert.equals(0, #marks)
    end)

    it("applies opencode edits in-place without reloading the live buffer", function()
      local edit = require("66.edit")
      local opencode = require("66.opencode")
      local ui = require("66.ui")
      local bufnr = test_utils.create_buffer({
        "local value = old()",
        "return value",
      }, "lua")
      local commands = {}

      vim.api.nvim_buf_set_name(bufnr, "/tmp/edit66-in-place.lua")
      patch_selection(1, 1, 1, 1, "V")
      test_utils.patch(ui, "capture_prompt", function(_, _, _, on_submit)
        on_submit("Use new_value()")
      end)
      test_utils.patch(opencode, "run", function(_, on_complete)
        vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "return other" })
        on_complete({ code = 0 }, "changed")
      end)
      test_utils.patch(vim.fn, "readfile", function(path)
        assert.equals("/tmp/edit66-in-place.lua", path)
        return {
          "local value = new_value()",
          "return value",
        }
      end)
      test_utils.patch(vim, "cmd", function(command)
        table.insert(commands, command)
        assert.is_nil(command:find("checktime", 1, true))
        assert.is_nil(command:find("edit!", 1, true))
      end)

      edit.run()

      assert.same({
        "local value = new_value()",
        "return other",
      }, test_utils.buffer_lines(bufnr))
      assert.same({ "silent noautocmd write!" }, commands)
    end)

    it("opens an error response when opencode fails", function()
      local edit = require("66.edit")
      local opencode = require("66.opencode")
      local ui = require("66.ui")
      local response

      test_utils.create_buffer({ "local value = old()" }, "lua")
      patch_selection(1, 1, 1, 1, "V")
      test_utils.patch(ui, "capture_prompt", function(_, _, _, on_submit)
        on_submit("Use new_value()")
      end)
      test_utils.patch(opencode, "run", function(_, on_complete)
        on_complete({ code = 23 }, "permission denied")
      end)
      test_utils.patch(ui, "open_scratch_response", function(name, lines, filetype)
        response = { name = name, lines = lines, filetype = filetype }
      end)
      test_utils.patch(vim, "cmd", function() end)

      edit.run()

      assert.equals("66 edit error", response.name)
      assert.equals("markdown", response.filetype)
      assert.equals("opencode exited with code 23", response.lines[1])
      assert.equals("permission denied", response.lines[3])
    end)

    it("notifies and skips opencode when no selection exists", function()
      local edit = require("66.edit")
      local opencode = require("66.opencode")
      local ui = require("66.ui")
      local notification

      test_utils.create_buffer({ "local value = old()" }, "lua")
      patch_selection(0, 0, 0, 0)
      test_utils.patch(vim, "notify", function(message, level)
        notification = { message = message, level = level }
      end)
      test_utils.patch(ui, "capture_prompt", function()
        error("prompt should not open without a selection")
      end)
      test_utils.patch(opencode, "run", function()
        error("opencode should not run without a selection")
      end)

      edit.run()

      assert.equals("Edit66 requires a visual selection", notification.message)
      assert.equals(vim.log.levels.ERROR, notification.level)
    end)
  end)
end)
