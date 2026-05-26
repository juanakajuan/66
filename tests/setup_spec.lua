local test_utils = require("tests.test_utils")

describe("66 setup", function()
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
end)
