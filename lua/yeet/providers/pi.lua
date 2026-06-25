local _PiProvider = {}

-- pane_id may be nil if not running as tmux
function _PiProvider.run_command(model_name, prompt, _, yeet)
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

return _PiProvider
