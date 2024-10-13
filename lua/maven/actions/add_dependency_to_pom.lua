local M = {}

local utils = require("maven.utils")

function M.add_dependency_to_pom()
  -- Função que define o comando para abrir o Maven Central de acordo com o SO
  local function get_open_command(os_name)
    if os_name == "Linux" or os_name == "FreeBSD" or os_name == "OpenBSD" or os_name == "NetBSD" then
      return { "xdg-open", "https://central.sonatype.com/" }, nil
    elseif os_name == "Darwin" then
      return { "open", "https://central.sonatype.com/" }, nil
    elseif os_name == "Windows_NT" then
      return { "cmd.exe", "/C", "start", "https://central.sonatype.com/" }, nil
    else
      return nil, "Unsupported OS"
    end
  end

  -- Abre o site do Maven Central
  utils.open_maven_central(get_open_command)

  -- Cria a janela flutuante
  local buf, win = utils.create_floating_window()

  -- Função para remover a mensagem de instrução
  local function remove_instruction()
    -- utils.create_floating_window.remove_instruction(buf, win)
    utils.remove_instruction(buf, win)
  end

  -- Configura o autocmd para remover a mensagem de instrução quando o usuário começar a digitar
  vim.defer_fn(function()
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged", "TextChangedP" }, {
      buffer = buf,
      callback = function()
        remove_instruction()
      end,
    })
  end, 500)

  -- Mapeia <enter> para fechar a janela e capturar o conteúdo
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    callback = function()
      local lines_dependency = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local dependency = table.concat(lines_dependency, "\n")

      if dependency == "" then
        vim.notify("No dependency provided", vim.log.levels.WARN)
        return
      end

      local function get_cwd()
        return require("maven.config").options.cwd or vim.fn.getcwd()
      end

      local pom_file = get_cwd() .. "/pom.xml"

      -- Lê o conteúdo do pom.xml
      local pom_content = table.concat(vim.fn.readfile(pom_file), "\n")

      -- Função para normalizar as strings
      local function normalize_string(str)
        return str:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
      end

      -- Função para verificar se a dependência já está presente
      local function is_dependency_present(p_content, dep)
        local normalized_dependency = normalize_string(dep)
        local normalized_pom_content = normalize_string(p_content)
        return normalized_pom_content:find(normalized_dependency, 1, true) ~= nil
      end

      if is_dependency_present(pom_content, dependency) then
        vim.notify("Dependency already exists in pom.xml", vim.log.levels.INFO)
        return
      end

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
      vim.api.nvim_win_close(win, true)
    end,
  })
end

return M
