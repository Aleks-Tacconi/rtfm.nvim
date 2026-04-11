local utils = require("rtfm.utils")

local M = {}

--- Waits before a sync request when a delay is configured.
--- @param delay_ms integer
--- @return nil
function M.wait(delay_ms)
	if delay_ms <= 0 then
		return
	end

	vim.wait(delay_ms)
end

--- Schedules an async callback with the configured request delay.
--- @param delay_ms integer
--- @param callback function
--- @return nil
function M.defer(delay_ms, callback)
	if delay_ms <= 0 then
		callback()
		return
	end

	vim.defer_fn(callback, delay_ms)
end

--- Fetches a URL synchronously with retry support.
--- @param crawler table
--- @param url string
--- @return string|nil
function M.fetch_html_sync(crawler, url)
	while true do
		local html = utils.curl(url)
		if html then
			return html
		end

		if not crawler.retry_failed_fetches then
			return nil
		end

		M.wait(crawler.retry_delay_ms)
	end
end

--- Fetches a URL asynchronously with retry support.
--- @param crawler table
--- @param url string
--- @param callback function
--- @return nil
function M.fetch_html_async(crawler, url, callback)
	local function attempt()
		utils.curl_async(url, function(ok, result)
			if ok then
				callback(true, result)
				return
			end

			if not crawler.retry_failed_fetches then
				callback(false, result)
				return
			end

			M.defer(crawler.retry_delay_ms, attempt)
		end)
	end

	attempt()
end

return M
