local BasicProvider = {}

-- pane_id may be nil if not running as tmux
function BasicProvider.run_command(model_name, prompt, cwd, yeet)
	local cmd = {
		"bash",
		"-c",
		"echo " .. prompt,
	}
	vim.notify("Running command " .. prompt .. " in " .. cwd .. " with model " .. model_name, vim.log.levels.INFO)

	return cmd,
		function(pane_id)
			vim.defer_fn(function()
				vim.notify(
					"Added command to pane "
						.. pane_id
						.. " after launch delay "
						.. vim.inspect(yeet.opts.timings.launch_delay),
					vim.log.levels.INFO
				)
				vim.defer_fn(function()
					vim.notify("Now sending with ENTER...", vim.log.levels.INFO)
				end, yeet.opts.timings.send_delay)
			end, yeet.opts.timings.launch_delay)
		end
end

return BasicProvider
