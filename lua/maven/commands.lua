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
  { cmd = actions.add_dependency_to_pom, desc = "Open Maven Central and add dependency" },
  { cmd = actions.create_project, desc = "Create Maven Project" },
}

return commands
