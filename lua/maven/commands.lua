local actions = require("maven.actions")

local commands = {
  ---@class MavenCommandOption
  ---@field cmd string[]
  ---@field desc string|nil
  { cmd = { "clean" } },
  { cmd = { "validate" } },
  { cmd = { "compile" } },
  { cmd = { "test" } },
  { cmd = { "package" } },
  { cmd = { "verify" } },
  { cmd = { "install" } },
  { cmd = { "site" } },
  { cmd = { "deploy" } },
  -- { cmd = { "archetype:generate" }, desc = "Create Maven Project" },
  { cmd = { "add-repository" }, desc = "Open Maven Central and add dependency" },
  { cmd = { "archetype:generate" }, desc = "Create Maven Project", action = actions.create_project },
}

return commands
