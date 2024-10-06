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

function maven.add_dependency_to_pom()
  -- Open Maven Central for OS
  local sysname = vim.loop.os_uname().sysname

  -- if not os_name then
  --   vim.notify("Error getting OS name: " .. os_name, vim.log.levels.ERROR)
  -- end

  -- if os_name == "Linux" then
  --   os.execute("xdg-open https://central.sonatype.com/ &")
  -- elseif os_name == "Darwin" then
  --   os.execute("open https://central.sonatype.com/ &")
  -- elseif os_name == "FreeBSD" or os_name == "OpenBSD" or os_name == "NetBSD" then
  --   os.execute("xdg-open https://central.sonatype.com/ &")
  -- elseif os_name == "Windows_NT" then
  --   os.execute("start https://central.sonatype.com/")
  -- else
  --   vim.notify("Unsupported operating system: " .. os_name, vim.log.levels.ERROR)
  --   return
  -- end

  local url_buf = vim.fn.termopen("xdg-open https://central.sonatype.com/", {
    on_exit = function()
      vim.cmd("bdelete!")
    end,
  })

  local cmd
  local buf = vim.api.nvim_create_buf(false, true)

  if sysname == "Linux" or sysname == "FreeBSD" or sysname == "OpenBSD" then
    cmd = "xdg-open https://central.sonatype.com/"
    -- vim.cmd("vnew") -- Cria um novo split
    -- vim.cmd("setlocal nobuflisted") -- Remove o buffer da lista de buffers
    -- vim.fn.termopen(cmd, {
    --   on_exit = function()
    --     vim.cmd("bdelete!")
    --   end,
    -- })
  elseif sysname == "Darwin" then
    cmdurl = "open "
  elseif sysname == "Windows_NT" then
    cmdurl = "start "
  else
    print("Unsupported OS: " .. sysname)
    return
  end

  -- vim.fn.termopen(cmd_url, {
  --   on_exit = function()
  --     vim.cmd("bdelete!")
  --   end,
  -- })

  vim.schedule(function()
    vim.fn.termopen(cmd, {
      on_exit = function()
        -- Fecha o buffer do terminal automaticamente
        vim.api.nvim_buf_delete(buf, { force = true })
      end,
    })
  end)

  -- Verifica se o arquivo pom.xml existe
  if not has_build_file(get_cwd()) then
    vim.notify("No pom.xml file found in the current directory", vim.log.levels.ERROR)
    return
  end

  -- Solicita a dependência a ser adicionada
  vim.ui.input({ prompt = "Paste the dependency snippet to add to pom.xml:" }, function(dependency)
    if not dependency or dependency == "" then
      vim.notify("No dependency provided", vim.log.levels.WARN)
      return
    end

    local pom_file = get_cwd() .. "/pom.xml"

    -- Lê o conteúdo do arquivo pom.xml
    local pom_content = table.concat(vim.fn.readfile(pom_file), "\n")

    -- Verifica se a dependência já está presente no pom.xml
    if pom_content:find(dependency, 1, true) then
      vim.notify("Dependency already exists in pom.xml", vim.log.levels.INFO)
      return
    end

    -- Se não encontrar, insere a dependência
    local lines = {}
    for line in io.lines(pom_file) do
      table.insert(lines, line)
    end

    -- Procura o fechamento da tag <dependencies> e insere antes
    local insert_index = nil
    for i, line in ipairs(lines) do
      if line:find("</dependencies>") then
        insert_index = i
        break
      end
    end

    if insert_index then
      table.insert(lines, insert_index, dependency)
    else
      vim.notify("No </dependencies> tag found in pom.xml", vim.log.levels.ERROR)
      return
    end

    -- Escreve as alterações de volta no pom.xml
    local file = io.open(pom_file, "w")

    if not file then
      vim.notify("Failed to open pom.xml for writing", vim.log.levels.ERROR)
      return
    end

    for _, line in ipairs(lines) do
      file:write(line .. "\n")
    end
    file:close()

    vim.notify("Dependency added to pom.xml", vim.log.levels.INFO)
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

  if command.cmd[1] == "add-repository" then
    -- Open  Maven Central
    maven.add_dependency_to_pom()
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
