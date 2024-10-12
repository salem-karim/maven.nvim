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
  {
    cmd = { "archetype:generate" }, -- Isso precisa ser uma string ou tabela de strings
    desc = "Create Maven Project",
    execute = function(callback)
      actions.create_project(function(command)
        -- O comando gerado é passado como uma string no callback
        callback(command)
      end)
    end,
  },
}

return commands
