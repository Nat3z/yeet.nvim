local git = require("yeet.git")

local _Yeet = {}

_Yeet.providers = {
	PiProvider = require("yeet.providers.pi"),
}
_Yeet.pane_id = ""

---@class yeet.Opts
---@field prompt? string|string[] prompt to run in the tmux pane. Defaults to /yeet
---@field provider any Provider instance
---@field model string Model passed to the command.
---@field timings? { launch_delay?: number, send_delay?: number, git_check_delay?: number, timeout?: number } Timing configuration for tmux operations. send_delay is the max wait before submitting if readiness detection fails.
---@field tmux? { size?: number, direction?: string }
---@field tmux_pane? { size?: number, direction?: string } Backwards-compatible alias for tmux.

-- normalizes tmux direction string to a compatible tmux option flag
local function normalize_tmux_direction(direction)
	if direction == nil or direction == "" then
		return "h"
	end

	local normalized = tostring(direction):lower()
	local aliases = {
		h = "h",
		horizontal = "h",
		v = "v",
		vertical = "v",
	}

	return aliases[normalized]
end

---@param opts yeet.Opts
function _Yeet.setup(opts)
	opts = opts or {}
	local tmux_opts = opts.tmux or opts.tmux_pane or {}
	local direction = normalize_tmux_direction(tmux_opts.direction)
	if direction == nil then
		vim.notify(
			"yeet: invalid tmux direction: "
				.. tostring(tmux_opts.direction)
				.. " (expected h/v or horizontal/vertical)",
			vim.log.levels.WARN
		)
		direction = "h"
	end

	_Yeet.opts = {
		prompt = opts.prompt or "/yeet",
		model = opts.model,
		provider = opts.provider,
		tmux = {
			size = tmux_opts.size or 25,
			direction = direction,
		},
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

function _Yeet.yeet_with_tmux(_, extra_prompt)
	if vim.env.TMUX == nil or vim.env.TMUX == "" then
		vim.notify("yeet: tmux mode needs to run inside tmux", vim.log.levels.WARN)
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

	local command, tmux_callback =
		_Yeet.opts.provider.run_tmux(_Yeet.opts.model, _Yeet.opts.prompt .. (extra_prompt or ""), cwd, _Yeet)
	local pane_id = vim.fn.systemlist({
		"tmux",
		"split-window",
		"-d",
		"-" .. _Yeet.opts.tmux.direction,
		"-p",
		tostring(_Yeet.opts.tmux.size),
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

function _Yeet.yeet_with_headless(_, extra_prompt)
	local cwd = vim.fn.getcwd()

	if _Yeet.opts.model == nil or _Yeet.opts.model == "" then
		vim.notify("yeet: opts.model is not set", vim.log.levels.ERROR)
		return
	end

	if not git.has_pending_work(cwd) then
		vim.notify("yeet: no pending git work to yeet", vim.log.levels.INFO)
		return
	end

	local command =
		_Yeet.opts.provider.run_headless(_Yeet.opts.model, _Yeet.opts.prompt .. " " .. (extra_prompt or ""), cwd, _Yeet)

	vim.notify("yeet: now yeeting...", vim.log.levels.DEBUG)
	local system_obj = vim.system(command, { cwd = cwd, text = true }, function(completed)
		vim.schedule(function()
			local output = (completed.stdout or "") .. (completed.stderr or "")
			local result = vim.split(vim.trim(output), "\n", { trimempty = true })

			if completed.code ~= 0 then
				vim.notify("yeet: failed to yeet", vim.log.levels.ERROR)
				if #result > 0 then
					vim.notify(vim.inspect(result), vim.log.levels.ERROR)
				end
			end
		end)
	end)

	local function check_status_loop()
		-- check if work was successfully applied
		if not git.has_pending_work(cwd) then
			vim.notify("yeet: yeeted successfully", vim.log.levels.INFO)
			system_obj:kill("SIGTERM")
		else
			vim.defer_fn(check_status_loop, _Yeet.opts.timings.git_check_delay)
		end
	end

	vim.defer_fn(check_status_loop, _Yeet.opts.timings.git_check_delay)

	vim.defer_fn(function()
		if system_obj and not system_obj:is_closing() then
			system_obj:kill("SIGTERM")
			vim.notify("yeet: timed out", vim.log.levels.ERROR)
		end
	end, _Yeet.opts.timings.timeout)
end

return _Yeet
