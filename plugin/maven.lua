local api = vim.api
local maven = require("maven")

api.nvim_create_user_command("Maven", function()
  maven.commands()
end, {})

api.nvim_create_user_command("MavenExec", function()
  vim.ui.input({ prompt = "Execute goal: " }, function(input)
    local command = maven.to_command(input)
    maven.execute_command(command)
  end)
end, {})

api.nvim_create_user_command("MavenAddDependency", function()
  vim.ui.input({ prompt = "Enter dependency to search: " }, function(input)
    if input then
      require("maven.dependencies").search_dependency(input)
    end
  end)
end, {})

api.nvim_create_user_command("MavenCreateProject", function()
  maven.create_project()
end, {})

vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
  callback = maven.kill_running_job,
})
