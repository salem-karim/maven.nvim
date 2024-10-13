local M = {}

local message = "Paste the dependency here and press enter to add it to the pom.xml."

-- Função para obter o comando de abrir URL dependendo do SO
local function get_open_command(os_name)
  if os_name == "Linux" or os_name == "FreeBSD" or os_name == "OpenBSD" or os_name == "NetBSD" then
    return { "xdg-open", "https://central.sonatype.com/" }
  elseif os_name == "Darwin" then
    return { "open", "https://central.sonatype.com/" }
  elseif os_name == "Windows_NT" then
    return { "cmd.exe", "/C", "start", "https://central.sonatype.com/" }
  else
    return nil, "Unsupported OS"
  end
end

-- Função para abrir o Maven Central no navegador
local function open_maven_central()
  local os_name = vim.loop.os_uname().sysname
  local cmd, err = get_open_command(os_name)

  if not cmd then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  -- Executa o comando em modo não bloqueante
  vim.loop.spawn(cmd[1], { args = { cmd[2] } }, function(code, _)
    if code ~= 0 then
      vim.notify("Failed to open URL", vim.log.levels.ERROR)
    end
  end)
end

-- Função para criar a janela flutuante onde o usuário colará a dependência
local function create_floating_window()
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 80,
    height = 10,
    row = 10,
    col = 10,
    style = "minimal",
    border = "rounded",
  })
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { message, "" })
  vim.api.nvim_win_set_cursor(win, { 2, 0 })

  return buf, win
end

-- Função para remover a mensagem de instrução quando o usuário começa a digitar
local function remove_instruction(buf, win)
  local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if first_line == message then
    vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})
    vim.api.nvim_win_set_cursor(win, { 1, 0 })
  end
end

-- Função para adicionar a dependência no arquivo pom.xml
local function add_dependency_to_pom_file(dependency)
  local get_cwd = function()
    return require("maven.config").options.cwd or vim.fn.getcwd()
  end

  local pom_file = get_cwd() .. "/pom.xml"
  local pom_content = table.concat(vim.fn.readfile(pom_file), "\n")

  -- Função auxiliar para normalizar strings (remover espaços extras)
  local function normalize_string(str)
    return str:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
  end

  -- Verifica se a dependência já existe no pom.xml
  local function is_dependency_present(p_content, dep)
    return normalize_string(p_content):find(normalize_string(dep), 1, true) ~= nil
  end

  if is_dependency_present(pom_content, dependency) then
    vim.notify("Dependency already exists in pom.xml", vim.log.levels.INFO)
    return
  end

  -- Insere a dependência no arquivo pom.xml
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
    local formatted_dependency =
      dependency:gsub("\n%s*<", "\n      <"):gsub("\n%s*</dependency>", "\n    </dependency>")
    table.insert(lines, insert_index, "    " .. formatted_dependency)
  else
    vim.notify("No </dependencies> tag found in pom.xml", vim.log.levels.ERROR)
    return
  end

  -- Salva o arquivo com a nova dependência
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
end

-- Função principal para adicionar a dependência ao pom.xml
function M.add_dependency_to_pom()
  -- Abre o Maven Central no navegador
  open_maven_central()

  -- Cria a janela flutuante
  local buf, win = create_floating_window()

  -- Remove a mensagem de instrução quando o usuário começa a digitar
  vim.defer_fn(function()
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged", "TextChangedP" }, {
      buffer = buf,
      callback = function()
        remove_instruction(buf, win)
      end,
    })
  end, 500)

  -- Mapeia a tecla <CR> para capturar o conteúdo e fechar a janela
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    callback = function()
      local lines_dependency = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local dependency = table.concat(lines_dependency, "\n")

      if dependency == "" then
        vim.notify("No dependency provided", vim.log.levels.WARN)
        return
      end

      -- Adiciona a dependência ao arquivo pom.xml
      add_dependency_to_pom_file(dependency)

      -- Fecha a janela flutuante
      vim.api.nvim_win_close(win, true)
    end,
  })
end

return M
