-- Read the docs: https://www.lunarvim.org/docs/configuratin
-- Example configs: https://github.com/LunarVim/starter.lvim
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

-- Enable powershell as your default shell
vim.opt.shell = "pwsh.exe"
vim.opt.shellcmdflag =
  "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command [Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8;"
vim.cmd [[
		let &shellredir = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
		let &shellpipe = '2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode'
		set shellquote= shellxquote=
  ]]

-- Set a compatible clipboard manager
vim.g.clipboard = {
  copy = {
    ["+"] = "win32yank.exe -i --crlf",
    ["*"] = "win32yank.exe -i --crlf",
  },
  paste = {
    ["+"] = "win32yank.exe -o --lf",
    ["*"] = "win32yank.exe -o --lf",
  },
}

-- Tab Width
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true


-- Relative Line Setup
vim.opt.relativenumber = true
vim.opt.number = true

-- Custom keybidings
vim.keymap.set('n', '<C-c>', '<Cmd>CopilotChat<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<Tab>', '<Cmd>wincmd W<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-f>', '<Cmd>Telescope live_grep<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-d>', '<Cmd>DBUI<CR>', { noremap = true, silent = true })
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })
vim.keymap.set('n', '<C-l>', '<Cmd>Telescope oldfiles<CR>', { noremap = true, silent = true })
vim.keymap.set('n', '<C-p>', '<Cmd>PasteAsSQL<CR>', { noremap = true, silent = true })

local lspconfig = require("lspconfig")
lspconfig.omnisharp.setup({
    cmd = { "omnisharp" }, -- Ensure it's in your PATH or provide full path
    enable_roslyn_analyzers = true,
    enable_import_completion = true,
    organize_imports_on_format = true,
    root_dir = lspconfig.util.root_pattern("*.sln", "*.csproj"),
    opts = function()
      local dap = require("dap")
      if not dap.adapters["netcoredbg"] then
        require("dap").adapters["netcoredbg"] = {
          type = "executable",
          command = vim.fn.exepath("netcoredbg"),
          args = { "--interpreter=vscode" },
          options = {
            detached = false,
          },
        }
      end
      for _, lang in ipairs({ "cs", "fsharp", "vb" }) do
        if not dap.configurations[lang] then
          dap.configurations[lang] = {
            {
              type = "netcoredbg",
              name = "Launch file",
              request = "launch",
              ---@diagnostic disable-next-line: redundant-parameter
              program = function()
                return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/", "file")
              end,
              cwd = "${workspaceFolder}",
            },
          }
        end
      end
    end
})

-- Put query into SQL acceptable format
function Paste_as_sql()
    -- Get the yanked text from the unnamed register
    local yanked_text = vim.fn.getreg('"')

    -- Find all variables indicated by @ signs
    local variables = {}
    for var in yanked_text:gmatch("@%w+") do
        table.insert(variables, var)
    end

    -- Remove duplicates from variables
    local unique_variables = {}
    for _, var in ipairs(variables) do
        unique_variables[var] = true
    end

    -- List of SQL types
    local sql_types = {"1. VARCHAR(MAX)", "2. INT", "3. FLOAT", "4. DATE", "5. BIT"}

    -- Default values and types for variables
    local defaults = {
        ["@timeSpanOffset"] = {value = "0", type = "INT"},
        ["@account"] = { type = "INT" },
        ["@date"] = { type = "DATE" }
    }

    -- Prompt for variable values and types
    local variable_declarations = ""
    for var, _ in pairs(unique_variables) do
        local value = defaults[var] and defaults[var].value or vim.fn.input("Enter value for " .. var .. ": ")
        local var_type
        if defaults[var] and defaults[var].type then
            var_type = defaults[var].type
        else
            local type_index = vim.fn.inputlist({"Choose type for " .. var .. ":", unpack(sql_types)})
            var_type = sql_types[type_index]:match("%d+%. (.+)")
        end
        variable_declarations = variable_declarations .. "DECLARE " .. var .. " " .. var_type .. " = '" .. value .. "';\n"
    end

    -- Remove unwanted characters and preserve necessary dots
    local processed_text = yanked_text
        :gsub('^[^"]*', "")         -- Remove everything before the first quote
        :gsub('"[^"]*$', "")         -- Remove everything after the first quote
        :gsub('"%s*%+%s*"', "")     -- Remove concatenation operators
        :gsub('"%s*', "")           -- Remove leading quotes
        :gsub('%s*"', "")           -- Remove trailing quotes

    -- Combine variable declarations with processed text
    local final_text = variable_declarations .. processed_text

    -- Update the unnamed register with the final text
    vim.fn.setreg('"', final_text)

    -- Paste the final text into the current buffer
    vim.api.nvim_paste(final_text, true, -1)
end

vim.cmd("command! PasteAsSQL lua Paste_as_sql()")

-- quickfix list delete keymap
function Remove_qf_item()
  local curqfidx = vim.fn.line('.')
  local qfall = vim.fn.getqflist()

  -- Return if there are no items to remove
  if #qfall == 0 then return end

  -- Remove the item from the quickfix list
  table.remove(qfall, curqfidx)
  vim.fn.setqflist(qfall, 'r')

  -- Reopen quickfix window to refresh the list
  vim.cmd('copen')

  -- If not at the end of the list, stay at the same index, otherwise, go one up.
  local new_idx = curqfidx < #qfall and curqfidx or math.max(curqfidx - 1, 1)

  -- Set the cursor position directly in the quickfix window
  local winid = vim.fn.win_getid() -- Get the window ID of the quickfix window
  vim.api.nvim_win_set_cursor(winid, {new_idx, 0})
end

vim.cmd("command! RemoveQFItem lua Remove_qf_item()")
vim.api.nvim_command("autocmd FileType qf nnoremap <buffer> dd :RemoveQFItem<cr>")

lvim.plugins = {
    { "EdenEast/nightfox.nvim" },
    { "Mofiqul/vscode.nvim" },
    { "pauchiner/pastelnight.nvim" },
    { "Enonya/yuyuko.vim" },
    { "neg-serg/neg.nvim" },
    { "github/copilot.vim" },
    { "tpope/vim-surround" },
    {
      'stevearc/oil.nvim',
      ---@module 'oil'
      ---@type oil.SetupOpts
      opts = {},
      dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if you prefer nvim-web-devicons
      lazy = false,
    },
    { "tpope/vim-dadbod",
        dependencies = {
            { "kristijanhusak/vim-dadbod-ui" },
            { "kristijanhusak/vim-dadbod-completion" },
        },
    },
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = {
          { "github/copilot.vim" }, -- or zbirenbaum/copilot.lua
          { "nvim-lua/plenary.nvim", branch = "master" }, -- for curl, log and async functions
        },
opts = {
      question_header = "## User ",
      answer_header = "## Copilot ",
      error_header = "## Error ",
      prompts = prompts,
      auto_follow_cursor = false, -- Don't follow the cursor after getting response
      mappings = {
        -- Use tab for completion
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        -- Close the chat
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        -- Reset the chat buffer
        reset = {
          normal = "<C-x>",
          insert = "<C-x>",
        },
        -- Submit the prompt to Copilot
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-CR>",
        },
        -- Accept the diff
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        -- Show help
        show_help = {
          normal = "g?",
        },
      },
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      chat.setup(opts)

      local select = require("CopilotChat.select")
      vim.api.nvim_create_user_command("CopilotChatVisual", function(args)
        chat.ask(args.args, { selection = select.visual })
      end, { nargs = "*", range = true })

      -- Inline chat with Copilot
      vim.api.nvim_create_user_command("CopilotChatInline", function(args)
        chat.ask(args.args, {
          selection = select.visual,
          window = {
            layout = "float",
            relative = "cursor",
            width = 1,
            height = 0.4,
            row = 1,
          },
        })
      end, { nargs = "*", range = true })

      -- Restore CopilotChatBuffer
      vim.api.nvim_create_user_command("CopilotChatBuffer", function(args)
        chat.ask(args.args, { selection = select.buffer })
      end, { nargs = "*", range = true })

      -- Custom buffer for CopilotChat
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-*",
        callback = function()
          vim.opt_local.relativenumber = true
          vim.opt_local.number = true

          -- Get current filetype and set it to markdown if the current filetype is copilot-chat
          local ft = vim.bo.filetype
          if ft == "copilot-chat" then
            vim.bo.filetype = "markdown"
          end
        end,
      })
    end,
    event = "VeryLazy",
    keys = {
      -- Show prompts actions with telescope
      {
        "<leader>ap",
        function()
          local actions = require("CopilotChat.actions")
          require("CopilotChat.integrations.telescope").pick(actions.prompt_actions())
        end,
        desc = "CopilotChat - Prompt actions",
      },
      {
        "<leader>ap",
        ":lua require('CopilotChat.integrations.telescope').pick(require('CopilotChat.actions').prompt_actions({selection = require('CopilotChat.select').visual}))<CR>",
        mode = "x",
        desc = "CopilotChat - Prompt actions",
      },
      -- Code related commands
      { "<leader>ae", "<cmd>CopilotChatExplain<cr>", desc = "CopilotChat - Explain code" },
      { "<leader>at", "<cmd>CopilotChatTests<cr>", desc = "CopilotChat - Generate tests" },
      { "<leader>ar", "<cmd>CopilotChatReview<cr>", desc = "CopilotChat - Review code" },
      { "<leader>aR", "<cmd>CopilotChatRefactor<cr>", desc = "CopilotChat - Refactor code" },
      { "<leader>an", "<cmd>CopilotChatBetterNamings<cr>", desc = "CopilotChat - Better Naming" },
      -- Chat with Copilot in visual mode
      {
        "<leader>av",
        ":CopilotChatVisual",
        mode = "x",
        desc = "CopilotChat - Open in vertical split",
      },
      {
        "<leader>ax",
        ":CopilotChatInline<cr>",
        mode = "x",
        desc = "CopilotChat - Inline chat",
      },
      -- Custom input for CopilotChat
      {
        "<leader>ai",
        function()
          local input = vim.fn.input("Ask Copilot: ")
          if input ~= "" then
            vim.cmd("CopilotChat " .. input)
          end
        end,
        desc = "CopilotChat - Ask input",
      },
      -- Generate commit message based on the git diff
      {
        "<leader>am",
        "<cmd>CopilotChatCommit<cr>",
        desc = "CopilotChat - Generate commit message for all changes",
      },
      -- Quick chat with Copilot
      {
        "<leader>aq",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            vim.cmd("CopilotChatBuffer " .. input)
          end
        end,
        desc = "CopilotChat - Quick chat",
      },
      -- Debug
      { "<leader>ad", "<cmd>CopilotChatDebugInfo<cr>", desc = "CopilotChat - Debug Info" },
      -- Fix the issue with diagnostic
      { "<leader>af", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "CopilotChat - Fix Diagnostic" },
      -- Clear buffer and chat history
      { "<leader>al", "<cmd>CopilotChatReset<cr>", desc = "CopilotChat - Clear buffer and chat history" },
      -- Toggle Copilot Chat Vsplit
      { "<leader>av", "<cmd>CopilotChatToggle<cr>", desc = "CopilotChat - Toggle" },
      -- Copilot Chat Models
      { "<leader>a?", "<cmd>CopilotChatModels<cr>", desc = "CopilotChat - Select Models" },
      -- Copilot Chat Agents
      { "<leader>aa", "<cmd>CopilotChatAgents<cr>", desc = "CopilotChat - Select Agents" },
    },
    },
}

lvim.colorscheme = "carbonfox"

