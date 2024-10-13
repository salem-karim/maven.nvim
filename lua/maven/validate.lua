local M = {}

local function has_build_file(cwd)
  return vim.fn.findfile("pom.xml", cwd) ~= ""
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

-- Função de validação para verificar as condições antes de executar o comando
function M.validate(cmd, cwd)
  if type(cmd.cmd) ~= "table" or not cmd.cmd[1] then
    return false, "Invalid command structure."
  end

  if cmd.cmd[1] ~= "create" and cmd.cmd[1] ~= "archetype:generate" and not has_build_file(cwd) then
    return false, "No pom.xml file found under " .. cwd
  end

  if cmd.cmd[1] == "archetype:generate" then
    -- Se houver um arquivo `pom.xml` no diretório
    if has_build_file(cwd) then
      if has_required_tag_in_pom(cwd, "packaging", "pom") then
        return true, "Required tag found in pom.xml. Proceeding with Maven project creation."
      else
        return false,
          "There is a pom.xml file indicating that there is already a Maven project in the directory: " .. cwd
      end
    else
      -- Se não houver `pom.xml`, é permitido criar o projeto
      return true, "No existing pom.xml found. Proceeding to create a new Maven project."
    end
  end

  -- Caso contrário, permite a execução do comando Maven normalmente
  return true, "Command is valid and can be executed."
end
return M
