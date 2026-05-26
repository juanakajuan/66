local test_utils = require("tests.test_utils")

describe("66.opencode", function()
  after_each(function()
    test_utils.cleanup()
    require("66.config").setup()
  end)

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
        test_utils.joined({
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
        test_utils.joined({
          '\27[0m→  \27[0mSkill "vim"',
          "I’ll inspect nearby modules first.",
          '\27[0m✱  \27[0mGlob "lua/66/*.lua" \27[90m in . · 11 matches \27[0m',
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
