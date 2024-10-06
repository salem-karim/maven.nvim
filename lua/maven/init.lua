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
  local os_name = vim.loop.os_uname().sysname

  if not os_name then
    vim.notify("Error getting OS name: " .. os_name, vim.log.levels.ERROR)
  end

  -- if os_name == "Linux" then
  --   os.execute("xdg-open https://central.sonatype.com/")
  -- elseif os_name == "Darwin" then
  --   os.execute("open https://central.sonatype.com/")
  -- elseif os_name == "Windows_NT" then
  --   os.execute("start https://central.sonatype.com/")
  -- else
  --   vim.notify("Unsupported operating system", vim.log.levels.ERROR)
  --   return
  -- end
  local cmd = {}
  if os_name == "Linux" then
    cmd = { "xdg-open", "https://central.sonatype.com/" }
  elseif os_name == "Darwin" then
    cmd = { "open", "https://central.sonatype.com/" }
  elseif os_name == "Windows_NT" then
    cmd = { "cmd.exe", "/C", "start", "https://central.sonatype.com/" }
  else
    vim.notify("Unsupported OS", vim.log.levels.ERROR)
    return
  end

  -- Executa o comando de forma não bloqueante
  vim.loop.spawn(cmd[1], { args = { cmd[2], cmd[3], cmd[4] } }, function(code, signal)
    if code ~= 0 then
      vim.notify("Failed to open URL", vim.log.levels.ERROR)
    end
  end)

  -- Cria um buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Abre uma janela flutuante com o buffer
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 80,
    height = 10,
    row = 10,
    col = 10,
    style = "minimal",
    border = "rounded",
  })

  -- Define o buffer como modificável
  vim.bo[buf].modifiable = true

  -- Define a instrução ao usuário
  vim.api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    false,
    { "Cole a dependência aqui e pressione enter para adicionar ao pom.xml.", "" }
  )

  -- Move o cursor para a linha abaixo da mensagem
  vim.api.nvim_win_set_cursor(win, { 2, 0 }) -- Linha 2, coluna 0

  -- Função para remover a mensagem de instrução
  local function remove_instruction()
    local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    if first_line == "Cole a dependência aqui e pressione enter para adicionar ao pom.xml." then
      -- Remova a primeira linha do buffer
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})
      -- Reposicione o cursor para a linha acima da próxima linha
      vim.api.nvim_win_set_cursor(win, { 1, 0 }) -- Ajuste a linha conforme necessário
    end
  end

  -- Adiciona um pequeno atraso antes de ativar o autocmd
  vim.defer_fn(function()
    -- Define o autocmd para remover a instrução assim que o usuário começar a editar ou colar texto
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged", "TextChangedP" }, {
      buffer = buf,
      callback = function()
        remove_instruction()
      end,
    })
  end, 500) -- 500 ms de atraso antes de ativar o autocmd

  -- Mapeia o <enter> para fechar a janela e capturar o conteúdo
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    callback = function()
      -- Captura as linhas do buffer
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local dependency = table.concat(lines, "\n")

      if dependency == "" then
        vim.notify("No dependency provided", vim.log.levels.WARN)
        return
      end

      -- Caminho do arquivo pom.xml
      local pom_file = get_cwd() .. "/pom.xml"

      -- Lê o conteúdo do arquivo pom.xml
      local pom_content = table.concat(vim.fn.readfile(pom_file), "\n")

      -- Função para normalizar strings (remover espaços extras)
      local function normalize_string(str)
        return str:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
      end

      -- Verifica se a dependência já está presente no pom.xml
      if pom_content:find(normalize_string(dependency), 1, true) then
        vim.notify("Dependency already exists in pom.xml", vim.log.levels.INFO)
        return
      end

      -- Insere a dependência antes da tag </dependencies>
      local lines = {}
      for line in io.lines(pom_file) do
        table.insert(lines, line)
      end

      local insert_index = nil
      for i, line in ipairs(lines) do
        if line:find("</dependencies>") then
          insert_index = i
          break
        end
      end

      if insert_index then
        -- Formata a dependência com indentação apropriada (4 espaços por nível)
        local formatted_dependency = string.format(
          "    %s",
          dependency:gsub("\n", "\n    ") -- Adiciona indentação a cada linha da dependência
        )
        table.insert(lines, insert_index, formatted_dependency)
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

      -- Fecha a janela após salvar
      vim.api.nvim_win_close(win, true)
    end,
  })
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
