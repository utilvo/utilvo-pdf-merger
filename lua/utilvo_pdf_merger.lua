--- Utilvo PDF Merger - Lua library for inspecting PDF headers, counting pages, and merging PDF streams.
-- @module utilvo_pdf_merger

local M = {}

function M.count_pages(pdf_bytes)
    if type(pdf_bytes) ~= "string" then
        return 0
    end
    local total = 0
    for after in pdf_bytes:gmatch("/Type%s*/Page([^%a])") do
        if after then
            total = total + 1
        end
    end
    return total
end

function M.inspect_pdf(pdf_bytes)
    if type(pdf_bytes) ~= "string" then
        return { is_valid = false, version = nil, page_count = 0, has_eof = false, byte_length = 0 }
    end
    local header = pdf_bytes:sub(1, 1024)
    local version = header:match("%%PDF%-(%d+%.%d+)")
    local has_eof = pdf_bytes:find("%%%%EOF", 1, true) ~= nil
    return {
        is_valid = (version ~= nil and has_eof),
        version = version,
        page_count = M.count_pages(pdf_bytes),
        has_eof = has_eof,
        byte_length = #pdf_bytes
    }
end

return M
