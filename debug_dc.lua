-- debug_dc.lua: tangkap semua variant saat DC

AddHook('OnVariant', 'dc_spy', function(var, netid, delay)
    local s = ""
    for i = 0, 5 do
        if var[i] ~= nil then
            s = s .. "[" .. i .. "]=" .. tostring(var[i]) .. " "
        end
    end
    LogToConsole("VAR: " .. s)
end)

LogToConsole("DC spy aktif")
