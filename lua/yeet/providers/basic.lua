local BasicProvider = {}

function BasicProvider.run_tmux(model_name, prompt, cwd, yeet)
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

function BasicProvider.run_headless(model_name, prompt, cwd, yeet)
	local cmd = {
		"bash",
		"-c",
		"echo " .. prompt,
	}
	vim.notify(
		"Running headless command "
			.. prompt
			.. " in "
			.. cwd
			.. " with model "
			.. model_name
			.. " in "
			.. vim.inspect(yeet),
		vim.log.levels.INFO
	)
	return cmd
end

return BasicProvider
