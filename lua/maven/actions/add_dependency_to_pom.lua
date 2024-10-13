local M = {}

local message = "Paste the dependency here and press enter to add it to the pom.xml."

function M.add_dependency_to_pom()
  -- Open Maven Central for OS
  ---@diagnostic disable-next-line: undefined-field
  local os_name = vim.loop.os_uname().sysname

  if not os_name then
    vim.notify("Error getting OS name: " .. os_name, vim.log.levels.ERROR)
  end

  local cmd = {}
  if os_name == "Linux" or os_name == "FreeBSD" or os_name == "OpenBSD" or os_name == "NetBSD" then
    cmd = { "xdg-open", "https://central.sonatype.com/" }
  elseif os_name == "Darwin" then
    cmd = { "open", "https://central.sonatype.com/" }
  elseif os_name == "Windows_NT" then
    cmd = { "cmd.exe", "/C", "start", "https://central.sonatype.com/" }
  else
    vim.notify("Unsupported OS", vim.log.levels.ERROR)
    return
  end

  -- Executes the command in a non-blocking manner
  ---@diagnostic disable-next-line: undefined-field
  vim.loop.spawn(cmd[1], { args = { cmd[2], cmd[3], cmd[4] } }, function(code, _)
    if code ~= 0 then
      vim.notify("Failed to open URL", vim.log.levels.ERROR)
    end
  end)

  -- Creates a buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Opens a floating window with the buffer
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = 80,
    height = 10,
    row = 10,
    col = 10,
    style = "minimal",
    border = "rounded",
  })

  -- Sets the buffer to be modifiable
  vim.bo[buf].modifiable = true

  -- Sets the instruction to the user
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { message, "" })

  -- Moves the cursor to the line below the message
  vim.api.nvim_win_set_cursor(win, { 2, 0 }) -- Linha 2, coluna 0

  -- Function to remove the instruction message
  local function remove_instruction()
    local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    if first_line == message then
      -- Removes the first line from the buffer
      vim.api.nvim_buf_set_lines(buf, 0, 1, false, {})
      -- Repositions the cursor to the line above the next line
      vim.api.nvim_win_set_cursor(win, { 1, 0 })
    end
  end
  -- Sets the autocmd to remove the instruction as soon as the user starts editing or pasting text
  vim.defer_fn(function()
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged", "TextChangedP" }, {
      buffer = buf,
      callback = function()
        remove_instruction()
      end,
    })
  end, 500)
  -- Maps <enter> to close the window and capture the content
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    noremap = true,
    callback = function()
      local lines_depedency = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local dependency = table.concat(lines_depedency, "\n")

      if dependency == "" then
        vim.notify("No dependency provided", vim.log.levels.WARN)
        return
      end

      local function get_cwd()
        return require("maven.config").options.cwd or vim.fn.getcwd()
      end

      local pom_file = get_cwd() .. "/pom.xml"

      -- Reads the content of the pom.xml file
      local pom_content = table.concat(vim.fn.readfile(pom_file), "\n")

      -- remove extra spaces
      local function normalize_string(str)
        return str:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1")
      end

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
        -- Formats the dependency with appropriate indentation
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
