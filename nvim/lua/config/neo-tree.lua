return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      window = {
        mappings = {
          ["<cr>"] = "open_with_window_picker", -- Opens file and closes neo-tree
        },
      },
    },
  },
}
