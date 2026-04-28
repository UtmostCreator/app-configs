-- ~/.config/nvim/lua/plugins/copilot.lua
return {
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        keymap = {
          accept = "<Tab>",
          accept_word = "<C-Right>",
          accept_line = "<C-l>",
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = { enabled = false }, -- suggestions via inline only
    },
  },
}
