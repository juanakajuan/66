local test_utils = require("tests.test_utils")

describe("66.context", function()
  after_each(function()
    test_utils.cleanup()
    require("66.config").setup()
  end)

  it("captures a charwise selection with line-numbered file context", function()
    local context = require("66.context")
    local bufnr = test_utils.create_buffer({
      "alpha",
      "local value = 1",
      "return value",
    }, "lua")
    vim.api.nvim_buf_set_name(bufnr, "/tmp/selection.lua")
    test_utils.patch_selection(2, 1, 2, 5)

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
    test_utils.patch_selection(4, 1, 2, 1, "V")

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
    test_utils.patch_selection(3, 1, 3, 5)

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
    test_utils.patch_selection(0, 0, 0, 0)

    local ok, err = pcall(context.selection)

    assert.is_false(ok)
    assert.equals("missing visual selection", err)
  end)
end)
