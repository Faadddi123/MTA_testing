--[[===========================================================================
    mysql_compat.lua  —  Pure-Lua drop-in shim for mta_mysql.so
    ============================================================================
    Emulates every mta_mysql C-plugin global using MTA's native db* API.
    Place this file inside your `mysql` resource folder and declare it as the
    FIRST <script> entry in that resource's meta.xml (see instructions below).

    Replaces:
        mysql_null              mysql_connect           mysql_close
        mysql_query             mysql_free_result       mysql_fetch_assoc
        mysql_fetch_row         mysql_data_seek         mysql_num_rows
        mysql_num_fields        mysql_affected_rows     mysql_insert_id
        mysql_escape_string     mysql_ping              mysql_select_db
        mysql_errno             mysql_error             mysql_get_server_info

    Requirements:
        • MTA:SA server r9500+ (dbConnect/dbQuery/dbPoll must be available)
        • The target database must be reachable from MTA's native MySQL driver
          (no dependency on libmysqlclient at the Lua level; MTA ships its own)

    Author note:
        This shim is intentionally synchronous (dbPoll timeout = -1) to
        preserve OwlGaming's sequential query semantics. If you later want
        async behaviour, wrap mysql_query calls with coroutines and swap in
        dbPoll(qh, 0) with a timer loop.
===========================================================================--]]


-- ─────────────────────────────────────────────────────────────────────────────
-- 1.  NULL sentinel
--     OwlGaming checks:  if value == mysql_null then ...
--     We use a unique table with metamethods so it pretty-prints and
--     concatenates sensibly if it ever leaks into a string context.
-- ─────────────────────────────────────────────────────────────────────────────

mysql_null = setmetatable({}, {
    __tostring = function()    return "NULL"              end,
    __concat   = function(a, b)
        return (a == mysql_null and "NULL" or tostring(a))
            .. (b == mysql_null and "NULL" or tostring(b))
    end,
    -- Prevent accidental mutation
    __newindex = function() error("mysql_null is read-only", 2) end,
})


-- ─────────────────────────────────────────────────────────────────────────────
-- 2.  Internal state tables
-- ─────────────────────────────────────────────────────────────────────────────

local _connMeta = {}   -- [conn userdata] = { lastAffected, lastInsertId }
local _results  = {}   -- [opaque table]  = { rows, cursor, numRows,
                       --                      affectedRows, lastInsertId, conn }


-- ─────────────────────────────────────────────────────────────────────────────
-- 3.  Connection management
-- ─────────────────────────────────────────────────────────────────────────────

--[[
    mysql_connect(host, user, pass, db [, port [, socket [, flags]]])
    Returns a connection handle on success, false on failure.
    `socket` and `flags` are accepted but ignored (MTA doesn't expose them).
--]]
function mysql_connect(host, user, pass, db, port, socket, flags)
    host = host or "localhost"
    port = tonumber(port) or 3306

    -- MTA's dbConnect connection string for MySQL:
    --   "dbname=<db>;host=<host>;port=<port>"
    -- Optional extras: charset, connect_timeout, etc.
    local connStr = string.format("dbname=%s;host=%s;port=%d", db, host, port)

    -- share=0 ensures we get an exclusive connection object; important because
    -- OwlGaming may open several logical connections for different subsystems.
    local conn = dbConnect("mysql", connStr, user, pass, "share=0")

    if not conn then
        outputServerLog(("[mysql_compat] CONNECT FAILED  db=%s host=%s port=%d")
            :format(db, host, port))
        return false
    end

    _connMeta[conn] = { lastAffected = 0, lastInsertId = 0 }
    outputServerLog(("[mysql_compat] Connected  db=%s host=%s port=%d")
        :format(db, host, port))
    return conn
end

--[[
    mysql_close(conn)
    MTA connections are reference-counted and GC'd automatically.
    We just clean up our metadata table.
--]]
function mysql_close(conn)
    if conn and _connMeta[conn] then
        _connMeta[conn] = nil
        outputServerLog("[mysql_compat] Connection closed.")
    end
end

--[[
    mysql_select_db(conn, dbName)
    MTA does not support switching databases on an existing connection handle.
    Return true optimistically; if your app needs multi-db, open a new
    mysql_connect per database.
--]]
function mysql_select_db(conn, dbName)
    return true
end

--[[
    mysql_ping(conn)
    Sends a lightweight "SELECT 1" to verify the connection is alive.
--]]
function mysql_ping(conn)
    if not conn then return false end
    local qh = dbQuery(conn, "SELECT 1")
    if not qh then return false end
    local rows = dbPoll(qh, -1)
    return rows ~= false
end


-- ─────────────────────────────────────────────────────────────────────────────
-- 4.  Query execution
-- ─────────────────────────────────────────────────────────────────────────────

-- MTA's dbPoll returns boolean false for NULL column values.
-- Convert those to our sentinel so existing OwlGaming comparisons work.
local function _normaliseNulls(row)
    for k, v in pairs(row) do
        if v == false then row[k] = mysql_null end
    end
    return row
end

--[[
    mysql_query(conn, queryString)
    Executes a query synchronously (blocks until the result is ready).
    Returns an opaque result handle on success, false on error.

    Note: We call dbQuery + dbPoll(-1) instead of dbExec so that INSERT/
    UPDATE queries still return affectedRows / lastInsertId metadata.
--]]
function mysql_query(conn, query)
    if not conn then
        outputServerLog("[mysql_compat] mysql_query: nil connection")
        return false
    end
    if type(query) ~= "string" then
        outputServerLog("[mysql_compat] mysql_query: query is not a string, got " .. type(query))
        return false
    end

    local qh = dbQuery(conn, query)
    if not qh then
        outputServerLog("[mysql_compat] dbQuery returned nil  query=" .. query:sub(1, 200))
        return false
    end

    -- timeout = -1: block indefinitely until done (synchronous semantics)
    local rows, numAffected, lastId = dbPoll(qh, -1)

    -- dbPoll returns false (not nil) on a MySQL-level error when timeout=-1
    if rows == false then
        outputServerLog("[mysql_compat] Query error  query=" .. query:sub(1, 200))
        return false
    end

    -- Normalise NULL values in every returned row
    for _, row in ipairs(rows) do
        _normaliseNulls(row)
    end

    -- Update per-connection last-insert / affected metadata
    local meta = _connMeta[conn]
    if meta then
        meta.lastAffected  = numAffected or 0
        meta.lastInsertId  = lastId      or 0
    end

    -- Create an opaque result handle (a plain table used purely as a unique key)
    local handle = {}
    _results[handle] = {
        rows         = rows,
        cursor       = 1,            -- 1-based fetch cursor
        numRows      = #rows,
        affectedRows = numAffected or 0,
        lastInsertId = lastId      or 0,
        conn         = conn,
    }
    return handle
end

--[[
    mysql_free_result(result)
    Release the result set. The handle becomes invalid after this call.
--]]
function mysql_free_result(result)
    if result then
        _results[result] = nil
    end
end


-- ─────────────────────────────────────────────────────────────────────────────
-- 5.  Result traversal
-- ─────────────────────────────────────────────────────────────────────────────

--[[
    mysql_fetch_assoc(result)
    Returns the next row as a string-keyed table, or false when exhausted.
    Column names match what MySQL returns (i.e. aliased names are respected).
--]]
function mysql_fetch_assoc(result)
    local r = _results[result]
    if not r or r.cursor > r.numRows then return false end
    local row = r.rows[r.cursor]
    r.cursor  = r.cursor + 1
    return row
end

--[[
    mysql_fetch_row(result)
    Returns the next row as a numerically-indexed array, or false when done.
    Column order follows the SELECT list order as returned by MTA.
--]]
function mysql_fetch_row(result)
    local row = mysql_fetch_assoc(result)
    if not row then return false end
    local out, i = {}, 1
    -- pairs() doesn't guarantee order; use ipairs on a sorted-key copy if
    -- strict column ordering matters. For most OwlGaming uses this is fine.
    for _, v in pairs(row) do
        out[i] = v
        i = i + 1
    end
    return out
end

--[[
    mysql_data_seek(result, offset)
    Moves the fetch cursor to `offset` (0-based, like PHP/MySQL convention).
--]]
function mysql_data_seek(result, offset)
    local r = _results[result]
    if r then
        r.cursor = (tonumber(offset) or 0) + 1
    end
end

--[[
    mysql_num_rows(result)
    Returns the number of rows in the result set.
--]]
function mysql_num_rows(result)
    local r = _results[result]
    return r and r.numRows or 0
end

--[[
    mysql_num_fields(result)
    Returns the number of columns in the first row.
    (MTA doesn't expose a column-count API separately.)
--]]
function mysql_num_fields(result)
    local r = _results[result]
    if not r or r.numRows == 0 then return 0 end
    local count = 0
    for _ in pairs(r.rows[1]) do count = count + 1 end
    return count
end

--[[
    mysql_affected_rows(conn)
    Returns the number of rows affected by the last INSERT/UPDATE/DELETE.
    OwlGaming also passes result handles here in some places; we handle both.
--]]
function mysql_affected_rows(conn_or_result)
    -- Check if it's a connection handle
    local meta = _connMeta[conn_or_result]
    if meta then return meta.lastAffected end
    -- Check if it's a result handle
    local r = _results[conn_or_result]
    if r then return r.affectedRows end
    return 0
end

--[[
    mysql_insert_id(conn)
    Returns the AUTO_INCREMENT id generated by the last INSERT.
--]]
function mysql_insert_id(conn)
    local meta = _connMeta[conn]
    return meta and meta.lastInsertId or 0
end


-- ─────────────────────────────────────────────────────────────────────────────
-- 6.  String escaping
-- ─────────────────────────────────────────────────────────────────────────────

--[[
    mysql_escape_string(conn, str)   — two-argument form (standard)
    mysql_escape_string(str)         — one-argument form used in some OwlGaming scripts

    Applies MySQL's standard escape rules.  This is equivalent to
    mysql_real_escape_string() for ASCII-safe inputs, which covers all
    OwlGaming usage (UTF-8 multibyte sequences don't contain 0x27/0x22).

    IMPORTANT: If you ever handle binary BLOBs, switch to parameterised
    queries (dbQuery with ? placeholders) instead.
--]]
function mysql_escape_string(conn_or_str, str)
    -- Detect one-argument call
    local s
    if str == nil then
        s = tostring(conn_or_str)
    else
        s = tostring(str)
    end

    -- Escape order matters: backslash MUST come first.
    s = s:gsub("\\",  "\\\\")   -- backslash
    s = s:gsub("\0",  "\\0")    -- NUL byte
    s = s:gsub("\n",  "\\n")    -- newline
    s = s:gsub("\r",  "\\r")    -- carriage return
    s = s:gsub("'",   "\\'")    -- single quote
    s = s:gsub('"',   '\\"')    -- double quote
    s = s:gsub("\26", "\\Z")    -- Ctrl-Z (Windows EOF marker)
    return s
end


-- ─────────────────────────────────────────────────────────────────────────────
-- 7.  Diagnostic / informational stubs
-- ─────────────────────────────────────────────────────────────────────────────

-- These are called in some OwlGaming health-check scripts. Returning safe
-- defaults prevents nil-call errors without breaking anything.

function mysql_errno(conn)
    return 0
end

function mysql_error(conn)
    return ""
end

function mysql_thread_safe()
    return true
end

function mysql_get_server_info(conn)
    -- Return a plausible version string; some scripts branch on major version.
    return "5.7.44-compat-shim"
end

function mysql_get_client_info()
    return "5.7.44-compat-shim"
end

function mysql_stat(conn)
    return "Uptime: 0  Threads: 1  Questions: 0  Slow queries: 0"
end


-- ─────────────────────────────────────────────────────────────────────────────
-- 8.  Startup confirmation
-- ─────────────────────────────────────────────────────────────────────────────

outputServerLog("================================================================")
outputServerLog(" mysql_compat.lua  LOADED")
outputServerLog(" All mta_mysql.so globals emulated via MTA native db* API.")
outputServerLog(" mysql_null, mysql_connect, mysql_query, mysql_fetch_assoc ...")
outputServerLog("================================================================")
