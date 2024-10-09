local maven = {}
local View = require("maven.view")
local commands = require("maven.commands")
local config = require("maven.config")
local uv = vim.loop
local actions = require("maven.actions.create_project")

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
    if cmd.cmd[1] == "archetype:generate" then
      actions.create_project()
      return
    end
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
  ---@diagnostic disable-next-line: undefined-field
  local os_name = uv.os_uname().sysname

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
  uv.spawn(cmd[1], { args = { cmd[2], cmd[3], cmd[4] } }, function(code, _)
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
  vim.api.nvim_buf_set_lines(
    buf,
    0,
    -1,
    false,
    { "Paste the dependency here and press enter to add it to the pom.xml.", "" }
  )

  -- Moves the cursor to the line below the message
  vim.api.nvim_win_set_cursor(win, { 2, 0 }) -- Linha 2, coluna 0

  -- Function to remove the instruction message
  local function remove_instruction()
    local first_line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    if first_line == "Paste the dependency here and press enter to add it to the pom.xml." then
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

local function has_required_tag_in_pom(cwd, tag, content)
  local pom_file = cwd .. "/pom.xml"

  -- Verifica se o arquivo existe
  if vim.fn.filereadable(pom_file) == 0 then
    return false
  end

  -- Lê o conteúdo do arquivo pom.xml
  local pom_content = table.concat(vim.fn.readfile(pom_file), "\n")

  -- Verifica se a tag com o conteúdo está presente
  local pattern = "<" .. tag .. ">%s*" .. content .. "%s*</" .. tag .. ">"
  return pom_content:match(pattern) ~= nil
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

  if command.cmd[1] == "archetype:generate" and has_build_file(cwd) then
    if has_required_tag_in_pom(cwd, "packaging", "pom") then
      vim.notify("Required tag found in pom.xml. Proceeding with Maven project creation.", vim.log.levels.INFO)
      maven.create_project()
    else
      vim.notify(
        "there is a pom.xml file that indicates, that there is a maven project in the directory " .. cwd,
        vim.log.levels.ERROR
      )
      return
    end
  elseif command.cmd[1] == "archetype:generate" and job == true then
    maven.create_project()
    job = false
    return
  end

  -- if command.cmd[1] == "create" then
  --   if has_build_file(cwd) then
  --     vim.notify(
  --       "there is a pom.xml file that indicates, that there is a maven project in the directory " .. cwd,
  --       vim.log.levels.ERROR
  --     )
  --   else
  --     maven.create_project()
  --   end
  --   return
  -- end

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
    ---@diagnostic disable-next-line: undefined-field
    uv.kill(job.pid, 15)
    job = nil
  end
end

return maven
