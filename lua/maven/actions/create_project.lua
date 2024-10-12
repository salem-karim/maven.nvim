local M = {}
--local maven = require("maven")
local config = require("maven.config")

-- on create project maven
function M.create_project()
  local default_group_id = "com.javaexample"
  local default_artifact_id = "javaexample"
  local default_archetype_id = "maven-archetype-quickstart"

  local cwd = config.options.cwd or vim.fn.getcwd()
  -- for create project

  -- Prompts user for input
  -- Checks whether the entered value is nil or empty, and applies the pattern if necessary

  vim.ui.input({ prompt = "ArchetypeId: (default: " .. default_archetype_id .. ")" }, function(archetypeId)
    archetypeId = (archetypeId ~= nil and archetypeId ~= "") and archetypeId or default_archetype_id

    vim.ui.input({ prompt = "ArtifactId: (default: " .. default_artifact_id .. ")" }, function(artifactId)
      artifactId = (artifactId ~= nil and artifactId ~= "") and artifactId or default_artifact_id

      vim.ui.input({ prompt = "GroupId: (default: " .. default_group_id .. ")" }, function(groupId)
        groupId = (groupId ~= nil and groupId ~= "") and groupId or default_group_id

        vim.notify("Executing Maven command: " .. table.concat({
          "archetype:generate",
          "-DgroupId=" .. groupId,
          "-DartifactId=" .. artifactId,
          "-DarchetypeArtifactId=" .. archetypeId,
          "-DinteractiveMode=false",
        }, " "))

        -- Run the Maven command to create the project in the cwd directory
        require("maven").execute_command({
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

return M
