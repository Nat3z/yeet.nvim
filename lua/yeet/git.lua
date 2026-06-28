local _Git = {}

local function git_status(cwd)
	local status = vim.fn.systemlist({ "git", "-C", cwd, "status", "--porcelain=v1", "--branch" })
	if vim.v.shell_error ~= 0 then
		return nil
	end

	return status
end

local function branch_has_upstream(branch_status)
	-- `git status --branch` prints `## branch...origin/branch` when an
	-- upstream is configured, and only `## branch` when it is not. Treat a
	-- missing upstream as pending work so yeet waits for `git push -u ...`, not
	-- just for local commits.
	return branch_status:find("...", 1, true) ~= nil
end

local function branch_is_synced(branch_status)
	local lower = branch_status:lower()
	return branch_has_upstream(branch_status)
		and lower:find("ahead", 1, true) == nil
		and lower:find("behind", 1, true) == nil
		and lower:find("gone", 1, true) == nil
end

function _Git.has_pending_work(cwd)
	local status = git_status(cwd)
	if status == nil then
		return false
	end

	for _, line in ipairs(status) do
		if line:sub(1, 2) ~= "##" then
			return true
		end

		if not branch_is_synced(line) then
			return true
		end
	end

	return false
end

function _Git.git_is_up_to_date(cwd)
	local status = git_status(cwd)
	if status == nil then
		return false
	end

	for _, line in ipairs(status) do
		if line:sub(1, 2) ~= "##" then
			return false
		end

		if not branch_is_synced(line) then
			return false
		end
	end

	return true
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

	if saw_work and _Git.git_is_up_to_date(cwd) then
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
