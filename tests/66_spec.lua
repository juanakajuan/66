local test_utils = require("tests.test_utils")

describe("66", function()
  after_each(function()
    test_utils.cleanup()
  end)

  it("registers user commands", function()
    require("66").setup({
      ask_keymap = false,
      explain_keymap = false,
      search_keymap = false,
      tutorial_keymap = false,
      history_keymap = false,
      edit_keymap = false,
    })

    assert.equals(2, vim.fn.exists(":Ask66"))
    assert.equals(2, vim.fn.exists(":Explain66"))
    assert.equals(2, vim.fn.exists(":Search66"))
    assert.equals(2, vim.fn.exists(":Tutorial66"))
    assert.equals(2, vim.fn.exists(":History66"))
    assert.equals(2, vim.fn.exists(":Edit66"))
  end)
end)
