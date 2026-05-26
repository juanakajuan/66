local test_utils = require("tests.test_utils")

describe("66.edit", function()
  after_each(function()
    test_utils.cleanup()
    require("66.config").setup()
  end)

  it("runs opencode with the selected context and clears status", function()
    local edit = require("66.edit")
    local opencode = require("66.opencode")
    local ui = require("66.ui")
    local bufnr = test_utils.create_buffer({
      "local value = old()",
      "return value",
    }, "lua")
    local captured_command

    test_utils.patch_selection(1, 1, 1, 1, "V")
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
    test_utils.patch_selection(1, 1, 1, 1, "V")
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

  it("opens quickfix for opencode edits outside the selected block", function()
    local edit = require("66.edit")
    local opencode = require("66.opencode")
    local ui = require("66.ui")
    local bufnr = test_utils.create_buffer({
      "local header = old_header()",
      "local value = old()",
      "return value",
    }, "lua")
    local commands = {}

    vim.api.nvim_buf_set_name(bufnr, "/tmp/edit66-outside.lua")
    test_utils.patch_selection(2, 1, 2, 1, "V")
    test_utils.patch(ui, "capture_prompt", function(_, _, _, on_submit)
      on_submit("Use new values")
    end)
    test_utils.patch(opencode, "run", function(_, on_complete)
      on_complete({ code = 0 }, "changed")
    end)
    test_utils.patch(vim.fn, "readfile", function(path)
      assert.equals("/tmp/edit66-outside.lua", path)
      return {
        "local header = new_header()",
        "local value = new_value()",
        "return value",
      }
    end)
    test_utils.patch(vim, "cmd", function(command)
      table.insert(commands, command)
    end)

    edit.run()

    local qf = vim.fn.getqflist({ title = 1, items = 1 })
    local first = qf.items[1]

    assert.same({
      "local header = new_header()",
      "local value = new_value()",
      "return value",
    }, test_utils.buffer_lines(bufnr))
    assert.same({ "silent noautocmd write!", "copen" }, commands)
    assert.equals("66 Edit: outside selected lines 2-2", qf.title)
    assert.equals(1, #qf.items)
    assert.equals("/tmp/edit66-outside.lua", first.filename or vim.fn.bufname(first.bufnr))
    assert.equals(1, first.lnum)
    assert.equals(1, first.col)
    assert.equals(1, first.end_lnum)
    assert.equals("66 Edit: outside selected lines 2-2", first.text)
  end)

  it("opens an error response when opencode fails", function()
    local edit = require("66.edit")
    local opencode = require("66.opencode")
    local ui = require("66.ui")
    local response

    test_utils.create_buffer({ "local value = old()" }, "lua")
    test_utils.patch_selection(1, 1, 1, 1, "V")
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
    test_utils.patch_selection(0, 0, 0, 0)
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
