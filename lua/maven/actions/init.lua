local M = {}

M.create_project = require("maven.actions.create_project").create_project
M.add_repository = require("maven.actions.add_repository_to_pom").add_repository_to_pom

return M
