local test_utils = require("tests.test_utils")

describe("66.ask", function()
  after_each(function()
    test_utils.cleanup()
    require("66.config").setup()
  end)

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

    test_utils.patch_selection(1, 1, 1, 1, "V")
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
