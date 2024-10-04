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
  { cmd = { "archetype:generate" }, desc = "Create a new Maven project" },
  { cmd = { "search-dependency" }, desc = "Search and add dependency to pom.xml" },
}

return commands
