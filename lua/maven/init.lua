local maven = {}
local View = require("maven.view")
local commands = require("maven.commands")
local config = require("maven.config")
local uv = vim.loop
local Job = require("plenary.job")

local view
local job

local json_ok, json = pcall(require, "json")
if not json_ok then
  json_ok, json = pcall(require, "dkjson")
  if not json_ok then
    vim.notify("JSON module not found, unable to parse search results", vim.log.levels.ERROR)
    return
  end
end

local function has_build_file(cwd)
  return vim.fn.findfile("pom.xml", cwd) ~= ""
end

local function get_cwd()
  local cwd = config.options.cwd or vim.fn.getcwd()
  return cwd
end

function maven.setup(options)
  config.setup(options)
  if config.options.commands ~= nil then
    for _, command in pairs(config.options.commands) do
      table.insert(commands, command)
    end
  end
end

function maven.commands()
  local prompt = "Execute maven goal (" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. ")"

  vim.ui.select(commands, {
    prompt = prompt,
    format_item = function(item)
      return item.desc or item.cmd[1]
    end,
  }, function(cmd)
    maven.execute_command(cmd)
  end)
end

---@return MavenCommandOption|nil
function maven.to_command(str)
  if str == nil or str == "" then
    return
  end
  local cmd = {}
  for command in str:gmatch("%S+") do
    table.insert(cmd, command)
  end
  return { cmd = cmd }
end

-- Search and Add Maven Dependency
function maven.search_dependency()
  vim.ui.input({ prompt = "Search Maven dependency:" }, function(query)
    if not query or query == "" then
      vim.notify("No search query provided", vim.log.levels.ERROR)
      return
    end

    local url = "https://search.maven.org/solrsearch/select?q=" .. query .. "&rows=20&wt=json"

    Job:new({
      command = "curl",
      args = { url },
      on_exit = function(job, return_val)
        local body = job:result()

        -- Verifica se houve erro na requisição
        if return_val ~= 0 then
          vim.notify("Failed to fetch dependencies from Maven Central", vim.log.levels.ERROR)
          return
        end

        -- Parseia o resultado JSON
        local result = json.decode(table.concat(body, "\n"))
        if not result or not result.response or #result.response.docs == 0 then
          vim.notify("No results found for query: " .. query, vim.log.levels.ERROR)
          return
        end

        -- Exibe as opções de dependências encontradas
        local dependencies = {}
        for _, doc in ipairs(result.response.docs) do
          table.insert(dependencies, {
            label = doc.g .. ":" .. doc.a .. " (v" .. doc.latestVersion .. ")",
            groupId = doc.g,
            artifactId = doc.a,
            version = doc.latestVersion,
          })
        end

        vim.ui.select(dependencies, {
          prompt = "Select a dependency to add:",
          format_item = function(item)
            return item.label
          end,
        }, function(choice)
          if choice then
            maven.add_dependency_to_pom(choice.groupId, choice.artifactId, choice.version)
          end
        end)
      end,
    }):start()
  end)
end

function maven.add_dependency_to_pom(groupId, artifactId, version)
  local cwd = get_cwd()
  local pom_path = cwd .. "/pom.xml"

  -- Verify pom.xml exist
  if not has_build_file(cwd) then
    vim.notify("No pom.xml file found in " .. cwd, vim.log.levels.ERROR)
    return
  end

  local pom_file = io.open(pom_path, "r")

  if not pom_file then
    vim.notify("Failed to open pom.xml for reading", vim.log.levels.ERROR)
    return
  end

  local pom_content = pom_file:read("*all")
  pom_file:close()

  local dependency_block = [[
<dependency>
  <groupId>%s</groupId>
  <artifactId>%s</artifactId>
  <version>%s</version>
</dependency>
]]
  local dependency_xml = string.format(dependency_block, groupId, artifactId, version)

  local new_pom_content = pom_content:gsub("(%s*</dependencies>)", dependency_xml .. "%1")

  local pom_file_write = io.open(pom_path, "w")

  if not pom_file_write then
    vim.notify("Failed to open pom.xml for writing", vim.log.levels.ERROR)
    return
  end

  pom_file_write:write(new_pom_content)
  pom_file_write:close()

  vim.notify("Dependency added successfully to pom.xml!", vim.log.levels.INFO)
end

-- on create project maven
function maven.create_project()
  local default_group_id = "com.javaexample"
  local default_artifact_id = "javaexample"
  local default_archetype_id = "maven-archetype-quickstart"

  local cwd = get_cwd() -- for create project

  -- Prompts user for input
  -- Checks whether the entered value is nil or empty, and applies the pattern if necessary
  vim.ui.input({ prompt = "GroupId: (default: " .. default_group_id .. ")" }, function(groupId)
    groupId = (groupId ~= nil and groupId ~= "") and groupId or default_group_id

    vim.ui.input({ prompt = "ArtifactId: (default: " .. default_artifact_id .. ")" }, function(artifactId)
      artifactId = (artifactId ~= nil and artifactId ~= "") and artifactId or default_artifact_id

      vim.ui.input({ prompt = "ArchetypeId: (default: " .. default_archetype_id .. ")" }, function(archetypeId)
        archetypeId = (archetypeId ~= nil and archetypeId ~= "") and archetypeId or default_archetype_id

        -- Run the Maven command to create the project in the cwd directory
        maven.execute_command({
          cmd = {
            "archetype:generate",
            "-DgroupId=" .. groupId,
            "-DartifactId=" .. artifactId,
            "-DarchetypeArtifactId=" .. archetypeId,
            "-DinteractiveMode=false",
          },
          cwd = cwd, -- Use the current directory to create the project
        })
      end)
    end)
  end)
end

function maven.execute_command(command)
  local cwd = get_cwd()

  if not command then
    vim.notify("No maven command")
    return
  end

  if command.cmd[1] ~= "create" and command.cmd[1] ~= "archetype:generate" and not has_build_file(cwd) then
    vim.notify("no pom.xml file found under " .. cwd, vim.log.levels.ERROR)
    return
  end

  if command.cmd[1] == "create" then
    if has_build_file(cwd) then
      vim.notify(
        "there is a pom.xml file that indicates, that there is a maven project in the directory " .. cwd,
        vim.log.levels.ERROR
      )
    else
      maven.create_project()
    end
    return
  end

  if command.cmd[1] == "add-dependency" then
    maven.search_dependency()
    return
  end

  maven.kill_running_job()

  local args = {}

  if config.options.settings ~= nil and config.options.settings ~= "" then
    table.insert(args, "-s")
    table.insert(args, config.options.settings)
  end

  for _, arg in pairs(command.cmd) do
    table.insert(args, arg)
  end

  view = View.create()

  job = require("plenary.job"):new({
    command = config.options.executable,
    args = args,
    cwd = cwd,
    on_stdout = function(_, data)
      view:render_line(data)
    end,
    on_stderr = function(_, data)
      vim.schedule(function()
        view:render_line(data)
      end)
    end,
  })

  view.job = job

  job:start()
end

function maven.kill_running_job()
  if job and job.pid then
    uv.kill(job.pid, 15)
    job = nil
  end
end

return maven
