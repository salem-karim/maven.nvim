local M = {}
local Job = require("plenary.job")

-- Function search depedency Maven Central
function M.search_dependency(dependency)
  local url = "https://search.maven.org/solrsearch/select?q=" .. dependency .. "&rows=10&wt=json"

  Job:new({
    command = "curl",
    args = { url },
    on_stdout = function(_, data)
      local results = vim.fn.json_decode(data)
      if results.response and results.response.docs then
        local docs = results.response.docs
        -- view list of dependencies for user
        local choices = {}
        for _, doc in ipairs(docs) do
          table.insert(choices, doc.g + ":" + doc.a + ":" + doc.latestVersion)
        end

        vim.ui.select(choices, { prompt = "Choose a dependency" }, function(choice)
          if choice then
            local parts = vim.split(choice, ":")
            M.add_to_pom(parts[1], parts[2], parts[3])
          end
        end)
      end
    end,
  }):start()
end

-- function add to pom.xml
function M.add_to_pom(groupId, artifactId, version)
  local pom_file = vim.fn.findfile("pom.xml", ".")
  if pom_file == "" then
    vim.notify("No pom.xml found", vim.log.levels.ERROR)
    return
  end

  local dependency_string = [[
<dependency>
  <groupId>]] .. groupId .. [[</groupId>
  <artifactId>]] .. artifactId .. [[</artifactId>
  <version>]] .. version .. [[</version>
</dependency>
]]

  vim.fn.writefile(vim.fn.readfile(pom_file) .. "\n" .. dependency_string, pom_file)
end

return M
