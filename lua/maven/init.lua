local maven = {}
local View = require("maven.view")
local commands = require("maven.commands")
local config = require("maven.config")
local uv = vim.loop

local view
local job

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

-- Função para buscar dependência no Maven Central usando curl
function maven.search_maven_central(groupId, artifactId)
  local url = "https://search.maven.org/solrsearch/select?q=g:"
    .. groupId
    .. "+AND+a:"
    .. artifactId
    .. "&rows=1&wt=json"
  local handle = io.popen('curl -s "' .. url .. '"')
  local result = handle:read("*a")
  handle:close()

  -- Processa o resultado
  if result and result:find('"response":{"numFound":0') then
    vim.notify("Dependency not found in Maven Central", vim.log.levels.ERROR)
    return nil
  end

  -- Retorna o JSON com a resposta bruta
  return result
end

-- Função para adicionar dependência no pom.xml
function maven.add_dependency_to_pom(groupId, artifactId, version)
  local pom_path = vim.fn.findfile("pom.xml")
  if pom_path == "" then
    vim.notify("No pom.xml found in current directory", vim.log.levels.ERROR)
    return
  end

  -- Estrutura XML da dependência a ser adicionada
  local dependency = [[
    <dependency>
      <groupId>]] .. groupId .. [[</groupId>
      <artifactId>]] .. artifactId .. [[</artifactId>
      <version>]] .. version .. [[</version>
    </dependency>
  ]]

  -- Abre o arquivo pom.xml e insere a dependência antes da tag </dependencies>
  local lines = {}
  for line in io.lines(pom_path) do
    if line:find("</dependencies>") then
      table.insert(lines, dependency)
    end
    table.insert(lines, line)
  end

  -- Escreve de volta no arquivo pom.xml
  local file = io.open(pom_path, "w")
  for _, line in ipairs(lines) do
    file:write(line .. "\n")
  end
  file:close()

  vim.notify("Dependency added to pom.xml", vim.log.levels.INFO)
end

-- Função para buscar e adicionar dependência
function maven.add_dependency(groupId, artifactId)
  -- Busca a dependência no Maven Central
  local result = maven.search_maven_central(groupId, artifactId)

  if result then
    -- Simplesmente buscar a versão do JSON retornado
    local version = result:match('"latestVersion":"([%d%.]+)"')
    if version then
      -- Adiciona a dependência ao pom.xml
      maven.add_dependency_to_pom(groupId, artifactId, version)
    else
      vim.notify("Unable to extract version from Maven Central response", vim.log.levels.ERROR)
    end
  end
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
