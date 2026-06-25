local git = require("yeet.git")

local _Yeet = {}

_Yeet.providers = {
	PiProvider = require("yeet.providers.pi"),
}

_Yeet.pane_id = ""

---@class yeet.Opts
---@field prompt? string|string[] prompt to run in the tmux pane. Defaults to /yeet
---@field model string Model passed to the command.
---@field timings? { launch_delay?: number, send_delay?: number, git_check_delay?: number, timeout?: number } Timing configuration for tmux operations.
---@field provider any Provider instance

function _Yeet.setup(opts)
	_Yeet.opts = {
		prompt = opts.prompt or "/yeet",
		model = opts.model,
		provider = opts.provider,
		timings = {
			launch_delay = opts.timings and opts.timings.launch_delay or 300,
			send_delay = opts.timings and opts.timings.send_delay or 900,
			git_check_delay = opts.timings and opts.timings.git_check_delay or 1000,
			timeout = opts.timings and opts.timings.timeout or 180000,
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

	local cwd = vim.fn.getcwd()

	if _Yeet.opts.model == nil or _Yeet.opts.model == "" then
		vim.notify("yeet: opts.model is not set", vim.log.levels.ERROR)
		return
	end

	if not git.has_pending_work(cwd) then
		vim.notify("yeet: no pending git work to yeet", vim.log.levels.INFO)
		return
	end

	local command, tmux_callback = _Yeet.opts.provider.run_command(_Yeet.opts.model, _Yeet.opts.prompt, cwd, _Yeet)
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
		unpack(command),
	})[1]

	_Yeet.pane_id = pane_id

	if tmux_callback then
		tmux_callback(pane_id)
	else
		vim.notify("yeet: provider does not support tmux callbacks", vim.log.levels.WARN)
	end

	vim.defer_fn(function()
		git.tmux_watch_git_up_to_date(_Yeet.pane_id, cwd)
	end, _Yeet.opts.timings.git_check_delay)

	vim.defer_fn(function()
		-- see if pane is still open first
		local panes = vim.fn.systemlist({ "tmux", "list-panes", "-F", "#{pane_id}" })
		local pane_exists = false
		for _, p in ipairs(panes) do
			if p == _Yeet.pane_id then
				pane_exists = true
				break
			end
		end
		if pane_exists then
			vim.fn.systemlist({ "tmux", "kill-pane", "-t", _Yeet.pane_id })
			vim.notify("yeet: timed out", vim.log.levels.ERROR)
		end
	end, _Yeet.opts.timings.timeout)
end

return _Yeet
