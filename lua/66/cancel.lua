local opencode = require("66.opencode")

local M = {}

function M.run()
  opencode.cancel_active()
end

return M
