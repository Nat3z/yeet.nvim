local _PiProvider = {}

local function pane_contains(pane_id, text)
	local lines = vim.fn.systemlist({ "tmux", "capture-pane", "-p", "-J", "-t", pane_id })
	return string.find(table.concat(lines, "\n"), text, 1, true) ~= nil
end

local function pane_exists(pane_id)
	local panes = vim.fn.systemlist({ "tmux", "list-panes", "-F", "#{pane_id}" })
	for _, p in ipairs(panes) do
		if p == pane_id then
			return true
		end
	end
	return false
end

function _PiProvider.run_tmux(model_name, prompt, _, yeet)
	local cmd = {
		"pi",
		"--model",
		model_name,
	}

	return cmd,
		function(pane_id)
			vim.defer_fn(function()
				if not pane_exists(pane_id) then
					return
				end

				vim.fn.system({ "tmux", "send-keys", "-t", pane_id, "-l", prompt })

				local started_at = vim.uv.now()
				local function press_enter_when_prompt_is_visible()
					if not pane_exists(pane_id) then
						return
					end

					if pane_contains(pane_id, prompt) and pane_contains(pane_id, "pi") then
						vim.fn.system({ "tmux", "send-keys", "-t", pane_id, "Enter" })
						return
					end

					if vim.uv.now() - started_at >= yeet.opts.timings.send_delay then
						vim.fn.system({ "tmux", "send-keys", "-t", pane_id, "Enter" })
						return
					end

					vim.defer_fn(press_enter_when_prompt_is_visible, 50)
				end

				press_enter_when_prompt_is_visible()
			end, yeet.opts.timings.launch_delay)
		end
end

function _PiProvider.run_headless(model_name, prompt, _, _)
	local cmd = {
		"pi",
		"--model",
		model_name,
		"-p",
		prompt,
	}
	return cmd
end

return _PiProvider
