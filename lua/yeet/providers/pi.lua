local _PiProvider = {}

function _PiProvider.run_tmux(model_name, prompt, _, yeet)
	local cmd = {
		"pi",
		"--model",
		model_name,
	}

	return cmd,
		function(pane_id)
			vim.defer_fn(function()
				vim.fn.system({ "tmux", "send-keys", "-t", pane_id, "-l", prompt })
				vim.defer_fn(function()
					vim.fn.system({ "tmux", "send-keys", "-t", pane_id, "Enter" })
				end, yeet.opts.timings.send_delay)
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
