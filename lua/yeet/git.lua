local _Git = {}

function _Git.has_pending_work(cwd)
	local porcelain = vim.fn.systemlist({ "git", "-C", cwd, "status", "--porcelain" })
	if vim.v.shell_error ~= 0 then
		return false
	end
	if #porcelain > 0 then
		return true
	end

	local status = table.concat(vim.fn.systemlist({ "git", "-C", cwd, "status" }), "\n"):lower()
	return status:find("ahead", 1, true) ~= nil
		or status:find("behind", 1, true) ~= nil
		or status:find("have diverged", 1, true) ~= nil
end

local function git_is_up_to_date(cwd)
	local porcelain = vim.fn.systemlist({ "git", "-C", cwd, "status", "--porcelain" })
	if vim.v.shell_error ~= 0 or #porcelain > 0 then
		return false
	end

	local status = table.concat(vim.fn.systemlist({ "git", "-C", cwd, "status" }), "\n"):lower()
	local clean = status:find("nothing to commit", 1, true) ~= nil or status:find("working tree clean", 1, true) ~= nil
	if not clean then
		return false
	end

	return status:find("up to date", 1, true) ~= nil
		or (
			status:find("ahead", 1, true) == nil
			and status:find("behind", 1, true) == nil
			and status:find("have diverged", 1, true) == nil
		)
end

function _Git.tmux_watch_git_up_to_date(pane_id, cwd, saw_work, checks)
	checks = checks or 0

	local panes = vim.fn.systemlist({ "tmux", "list-panes", "-F", "#{pane_id}", "-t", pane_id })
	if vim.v.shell_error ~= 0 or #panes == 0 then
		return
	end

	if _Git.has_pending_work(cwd) then
		saw_work = true
	end

	if saw_work and git_is_up_to_date(cwd) then
		vim.notify("Git is up to date; closing tmux pane " .. pane_id, vim.log.levels.INFO)
		vim.fn.system({ "tmux", "kill-pane", "-t", pane_id })
		return
	end

	if checks >= 2000 then
		vim.notify("Stopped watching for git up to date", vim.log.levels.WARN)
		return
	end

	vim.defer_fn(function()
		_Git.tmux_watch_git_up_to_date(pane_id, cwd, saw_work, checks + 1)
	end, 600)
end

return _Git
