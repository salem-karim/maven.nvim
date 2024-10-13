local M = {}

local function has_build_file(cwd)
  return vim.fn.findfile("pom.xml", cwd) ~= ""
end

-- Função de validação para verificar as condições antes de executar o comando
function M.validate(cmd, cwd)
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
