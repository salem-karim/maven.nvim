local M = {}

-- on create project maven
function M.create_project(callback)
  local default_group_id = "com.javaexample"
  local default_artifact_id = "javaexample"
  local default_archetype_id = "maven-archetype-quickstart"

  -- Prompts user for input
  -- Checks whether the entered value is nil or empty, and applies the pattern if necessary
  vim.ui.input({ prompt = "GroupId: (default: " .. default_group_id .. ")" }, function(groupId)
    groupId = (groupId ~= nil and groupId ~= "") and groupId or default_group_id
    vim.ui.input({ prompt = "ArtifactId: (default: " .. default_artifact_id .. ")" }, function(artifactId)
      artifactId = (artifactId ~= nil and artifactId ~= "") and artifactId or default_artifact_id

      vim.ui.input({ prompt = "ArchetypeId: (default: " .. default_archetype_id .. ")" }, function(archetypeId)
        archetypeId = (archetypeId ~= nil and archetypeId ~= "") and archetypeId or default_archetype_id

        local cmd = string.format(
          "archetype:generate -DgroupId=%s -DartifactId=%s -DarchetypeArtifactId=%s -DinteractiveMode=false",
          groupId,
          artifactId,
          archetypeId
        )
        local command = {
          cmd = cmd, -- Este é o comando a ser executado
          desc = "Create Maven Project", -- Uma descrição opcional
        }
        callback(command)
      end)
    end)
  end)
end
return M
