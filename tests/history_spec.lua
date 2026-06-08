local test_utils = require("tests.test_utils")

describe("66.history", function()
  after_each(function()
    test_utils.cleanup()
    require("66.config").setup()
  end)

  it("lists 66 sessions through opencode transport and opens the selected export", function()
    local history = require("66.history")
    local opencode = require("66.opencode")
    local ui = require("66.ui")
    local commands = {}
    local stopped = {}
    local response

    test_utils.patch(ui, "start_status_throbber", function(label)
      return function()
        table.insert(stopped, label)
      end
    end)
    test_utils.patch(opencode, "run_raw", function(command, on_complete)
      table.insert(commands, command)

      if command[2] == "session" then
        on_complete(
          { code = 0 },
          "log line\n"
            .. vim.json.encode({
              { id = "ignore", title = "Other session", updated = 1700000000000 },
              { id = "keep", title = "[66] Search: auth", updated = 1700000000000 },
            }),
          { canceled = false }
        )
        return
      end

      on_complete(
        { code = 0 },
        vim.json.encode({
          info = { title = "[66] Search: auth", time = { updated = 1700000000000 } },
          messages = {
            {
              info = { role = "assistant" },
              parts = {
                { type = "text", text = "First answer." },
                { type = "tool", text = "ignored" },
              },
            },
            {
              info = { role = "assistant" },
              parts = {
                { type = "text", text = "Second answer." },
              },
            },
          },
        }),
        { canceled = false }
      )
    end)
    test_utils.patch(vim.ui, "select", function(items, opts, on_choice)
      assert.equals("66 session history", opts.prompt)
      assert.equals(1, #items)
      assert.is_true(opts.format_item(items[1]):find("%[66%] Search: auth") ~= nil)
      on_choice(items[1])
    end)
    test_utils.patch(ui, "open_scratch_response", function(name, lines, filetype)
      response = { name = name, lines = lines, filetype = filetype }
    end)

    history.run()

    assert.same({
      { "opencode", "session", "list", "--format", "json", "--max-count", "50" },
      { "opencode", "export", "keep" },
    }, commands)
    assert.same({ "Loading history", "Loading session" }, stopped)
    assert.equals("66 history", response.name)
    assert.equals("markdown", response.filetype)
    assert.equals("# [66] Search: auth", response.lines[1])
    assert.equals("First answer.", response.lines[5])
    assert.equals("Second answer.", response.lines[7])
  end)

  it("stops loading and skips output when session list is canceled", function()
    local history = require("66.history")
    local opencode = require("66.opencode")
    local ui = require("66.ui")
    local complete
    local stopped = false

    test_utils.patch(ui, "start_status_throbber", function()
      return function()
        stopped = true
      end
    end)
    test_utils.patch(opencode, "run_raw", function(_, on_complete)
      complete = on_complete
    end)
    test_utils.patch(vim.ui, "select", function()
      error("history should not select canceled output")
    end)
    test_utils.patch(ui, "open_scratch_response", function()
      error("history should not open canceled output")
    end)

    history.run()
    complete({ code = 143 }, "", { canceled = true })

    assert.is_true(stopped)
  end)
end)
