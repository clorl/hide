local success, result

vim.o.makeprg = vim.fs.normalize("./build-and-run.bat")

vim.opt.expandtab = false
vim.o.list = true
vim.opt.listchars = {
		tab = '» ',
}
vim.opt.errorformat = {
  "%E %*\\s%f:%l: characters %c-%c",
  "%Z %*\\s| %m",
}

if Snacks ~= nil then
  vim.keymap.set("n", "<leader>g", function() Snacks.picker.grep({
    glob = "**/*.{hx,hxml}"
  }) end, { desc = "Grep" })
  vim.keymap.set("n", "<leader>G", function() Snacks.picker.grep() end, { desc = "Grep All" })
end

success, result = pcall(require, "overseer")
if success then
  local overseer = result

  result.register_template({
    name = "Build",
    builder = function(_)
      return {
        name = "Build Hide",
				cmd = { "haxe", "hide.hxml"},
      }
    end
  })

  result.register_template({
    name = "Compile Less",
    builder = function(_)
      return {
        name = "Compile Less",
				strategy = {
					"orchestrator",
					tasks = {
						{ "shell", cmd = "lessc bin/style.less bin/style.css" },
						{ "shell", cmd = "lessc bin/cdb.less bin/cdb.css" },
					}
				}
      }
    end
  })
end
