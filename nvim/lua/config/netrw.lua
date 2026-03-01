-- Create a new file at ~/.config/nvim/lua/config/netrw.lua
return function()
  -- Close netrw when opening a file
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "netrw",
    desc = "Close netrw after selecting file",
    callback = function()
      -- Map enter to open and close netrw
      vim.keymap.set("n", "<CR>", function()
        local selected = vim.fn.expand("%")
        vim.cmd(":wincmd l") -- Move to the right window if split
        vim.cmd(":q") -- Close netrw
        vim.cmd(":e " .. selected) -- Open the selected file
      end, { buffer = true })
    end,
  })
end
