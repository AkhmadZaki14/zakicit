-- test_g.lua: cek apakah _G ada

if _G ~= nil then
    LogToConsole("_G ada: " .. tostring(_G))
else
    LogToConsole("_G nil!")
end
