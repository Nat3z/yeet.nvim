# yeet.nvim

a neovim plugin that makes yeeting your changes to git even easier.

uses ai with a locally installed harness for yeeting your changes to git.

## Installation

### with lazy.nvim

```lua
{
    "nat3z/yeet.nvim",
    cmd = { "Yeet" },
    config = function()
        local yeet = require("yeet")
        yeet.setup({
            -- this model is the provider/slug identified by your harness.
            model = "<provider>/<model slug>", -- e.g., openai-codex/gpt-5.4-mini.

            -- use a skill, command, or prompt to tell the agent how to yeet
            prompt = "<your skill or prompt to yeet changes>", 

            -- the model provider used to yeet your changes
            provider = yeet.providers.PiProvider, -- available options: PiProvider

            -- timings for tmux when your harness is launching and when to send keys
            -- all numbers are in (ms)
            timings = {
                launch_delay = 300, -- time to wait before sending keys for your prompt
                send_delay = 900, -- max time to wait before submitting if tmux readiness detection fails
                git_check_delay = 1000, -- loop time to poll git to see if changes were committed
                timeout = 180000, -- maximum time to wait for the model to push changes
            }
        })

        vim.keymap.set("n", "<leader>gy", function()
            if vim.env.TMUX == nil or vim.env.TMUX == "" then
                yeet.yeet_with_headless() -- runs without tmux, will just provide vim notification
            else
                yeet.yeet_with_tmux() -- runs using tmux, will open a split pane to see output
            end
        end, { desc = "yeet: commit and push changes" })
    end,
}
```

### other package managers

ur a nerd you probably already know how to do it
