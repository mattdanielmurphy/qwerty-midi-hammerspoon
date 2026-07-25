local startTime = os.clock()
local function logp(msg)
    local fd = io.open("/tmp/hs_profile.log", "a")
    if fd then
        fd:write(string.format("[%.4fs] %s\n", os.clock() - startTime, msg))
        fd:close()
    end
end
os.execute("rm -f /tmp/hs_profile.log")
logp("Starting test script")
