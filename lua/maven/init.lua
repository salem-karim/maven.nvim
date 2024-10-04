local maven = {}
local View = require("maven.view")
local commands = require("maven.commands")
local config = require("maven.config")
local uv = vim.loop
local is_creating_project = false

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

function maven.execute_command(command)
  if command == nil then
    vim.notify("No maven command")
    return
  end

  local cwd = get_cwd()
  if is_creating_project then
    vim.notify("Project creation is already in progress.")
  end

  if not has_build_file(cwd) and not is_creating_project then
    vim.notify("no pom.xml file found under " .. cwd, vim.log.levels.ERROR)
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

-- Função para criar um novo projeto Maven interativamente
function maven.create_project()
  is_creating_project = true
  -- Definir valores padrão
  local default_archetype = "maven-archetype-quickstart"
  local default_group_id = "com.newproject"
  local default_artifact_id = "newproject"

  -- Pedir entradas interativas
  vim.ui.input({ prompt = "Enter groupId: (default: " .. default_group_id .. ")" }, function(groupId)
    groupId = groupId ~= "" and groupId or default_group_id

    vim.ui.input({ prompt = "Enter artifactId: (default: " .. default_artifact_id .. ")" }, function(artifactId)
      artifactId = artifactId ~= "" and artifactId or default_artifact_id

      vim.ui.input(
        { prompt = "Enter archetypeArtifactId: (default: " .. default_archetype .. ")" },
        function(archetypeArtifactId)
          archetypeArtifactId = archetypeArtifactId ~= "" and archetypeArtifactId or default_archetype

          -- Preparar o comando Maven para criar o projeto
          local cmd = {
            "archetype:generate",
            "-DgroupId=" .. groupId,
            "-DartifactId=" .. artifactId,
            "-DarchetypeArtifactId=" .. archetypeArtifactId,
          }

          -- Executar o comando Maven
          maven.execute_command({ cmd = cmd })
        end
      )
    end)
  end)
end

return maven
