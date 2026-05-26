local test_utils = require("tests.test_utils")

describe("66.search", function()
  after_each(function()
    test_utils.cleanup()
    require("66.config").setup()
  end)

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
        test_utils.joined({
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
