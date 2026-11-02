-- test_request.lua: cek apakah MakeRequest bisa kontak localhost

local res = MakeRequest and MakeRequest("http://127.0.0.1:9999/ping", "GET")
if res then
    LogToConsole("MakeRequest jalan! status: " .. tostring(res.status))
else
    LogToConsole("MakeRequest nil / gagal")
end
