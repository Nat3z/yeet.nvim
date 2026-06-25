local git = require("yeet.git")

local _Yeet = {}

---@class yeet.Opts
---@field command? string|string[] Command to run in the tmux pane. Defaults to /yeet
---@field model string Model passed to the command.
---@field timings? { launch_delay?: number, send_delay?: number, git_check_delay?: number } Timing configuration for tmux operations.

function _Yeet.setup(opts)
	_Yeet.opts = {
		command = opts.command or "/yeet",
		model = opts.model,
		timings = opts.timings or {
			launch_delay = 300,
			send_delay = 800,
			git_check_delay = 1000,
		},
	}

	vim.api.nvim_create_user_command("Yeet", function(cmd)
		if #cmd.args == 0 then
			_Yeet.yeet_with_tmux()
			return
		end

		if cmd.args == "tmux" then
			_Yeet.yeet_with_tmux()
		else
			vim.notify("Unknown argument: " .. cmd.args, vim.log.levels.ERROR)
		end
	end, { desc = "Runs yeet.nvim" })
end

function _Yeet.yeet_with_tmux()
	if vim.env.TMUX == nil or vim.env.TMUX == "" then
		vim.notify("yeet needs to run inside tmux", vim.log.levels.WARN)
		return
	end

	if _Yeet.opts.model == nil or _Yeet.opts.model == "" then
		vim.notify("yeet: opts.model is not set", vim.log.levels.ERROR)
		return
	end

	local cwd = vim.fn.getcwd()
	local pane_id = vim.fn.systemlist({
		"tmux",
		"split-window",
		"-d",
		"-h",
		"-p",
		"25",
		"-c",
		cwd,
		"-P",
		"-F",
		"#{pane_id}",
		"pi",
		"--model",
		_Yeet.opts.model,
	})[1]

	vim.notify("Opened pi in tmux pane " .. pane_id .. "; sending " .. _Yeet.opts.command, vim.log.levels.INFO)
	vim.defer_fn(function()
		vim.fn.system({ "tmux", "send-keys", "-t", pane_id, "-l", _Yeet.opts.command })
		vim.defer_fn(function()
			vim.fn.system({ "tmux", "send-keys", "-t", pane_id, "Enter" })
			vim.defer_fn(function()
				git.tmux_watch_git_up_to_date(pane_id, cwd)
			end, _Yeet.opts.timings.git_check_delay)
		end, _Yeet.opts.timings.send_delay)
	end, _Yeet.opts.timings.launch_delay)
end

return _Yeet
