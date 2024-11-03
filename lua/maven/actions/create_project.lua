local M = {}

function M.create_project(callback)
  local default_group_id = "com.javaexample"
  local default_artifact_id = "javaexample"
  local default_archetype_id = "maven-archetype-quickstart"
  local default_version = "1.5"

  -- Prompts user for input
  vim.ui.input({ prompt = "GroupId: (default: " .. default_group_id .. ")" }, function(groupId)
    groupId = (groupId ~= nil and groupId ~= "") and groupId or default_group_id

    vim.ui.input({ prompt = "ArtifactId: (default: " .. default_artifact_id .. ")" }, function(artifactId)
      artifactId = (artifactId ~= nil and artifactId ~= "") and artifactId or default_artifact_id

      vim.ui.input({ prompt = "ArchetypeId: (default: " .. default_archetype_id .. ")" }, function(archetypeId)
        archetypeId = (archetypeId ~= nil and archetypeId ~= "") and archetypeId or default_archetype_id

        -- Check if it's the quickstart archetype
        if archetypeId == "maven-archetype-quickstart" then
          -- Show available versions and prompt for version
          vim.ui.input({ prompt = "Version (default: " .. default_version .. "): " }, function(version)
            version = (version ~= nil and version ~= "") and version or default_version

            local cmd = string.format(
              "archetype:generate -DgroupId=%s -DartifactId=%s -DarchetypeArtifactId=%s -DarchetypeVersion=%s -DinteractiveMode=false",
              groupId,
              artifactId,
              archetypeId,
              version
            )
            callback({ cmd = cmd })
          end)
        else
          -- For other archetypes, don't include version
          local cmd = string.format(
            "archetype:generate -DgroupId=%s -DartifactId=%s -DarchetypeArtifactId=%s -DinteractiveMode=false",
            groupId,
            artifactId,
            archetypeId
          )
          callback({ cmd = cmd })
        end
      end)
    end)
  end)
end

return M
