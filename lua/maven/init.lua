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

function maven.execute_command(command)
  if command == nil then
    vim.notify("No maven command")
    return
  end

  local cwd = get_cwd()

  if not has_build_file(cwd) then
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

function maven.create_project()
  -- Solicitar o groupId ao usuário
  vim.ui.input({ prompt = "Enter groupId (default: com.newproject): " }, function(groupId)
    -- Se groupId for vazio ou nil, use o valor padrão "com.newproject"
    groupId = groupId == nil or groupId == "" and "com.newproject" or groupId

    -- Solicitar o artifactId ao usuário
    vim.ui.input({ prompt = "Enter artifactId (default: newproject): " }, function(artifactId)
      -- Se artifactId for vazio ou nil, use o valor padrão "newproject"
      artifactId = artifactId == nil or artifactId == "" and "newproject" or artifactId

      -- Solicitar o archetypeArtifactId ao usuário
      vim.ui.input(
        { prompt = "Enter archetypeArtifactId (default: maven-archetype-quickstart): " },
        function(archetypeArtifactId)
          -- Se archetypeArtifactId for vazio ou nil, use o valor padrão "maven-archetype-quickstart"
          archetypeArtifactId = archetypeArtifactId == nil
            or archetypeArtifactId == "" and "maven-archetype-quickstart"
            or archetypeArtifactId

          -- Construir o comando Maven com os valores inseridos ou padrões
          local command = {
            cmd = {
              "archetype:generate",
              "-DgroupId=" .. groupId,
              "-DartifactId=" .. artifactId,
              "-DarchetypeArtifactId=" .. archetypeArtifactId,
              "-DinteractiveMode=false",
            },
          }

          -- Executar o comando Maven
          maven.execute_command(command)
        end
      )
    end)
  end)
end

return maven
