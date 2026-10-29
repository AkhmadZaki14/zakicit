# ZAKICIT PNB v2 — Ultimate Consolidated Edition

Script auto PNB Growtopia (Bothax / Powerkuy / executor Lua).

## Quick Exec (One-Liner)

Paste ini di executor:

```lua
local res = MakeRequest("https://raw.githubusercontent.com/AkhmadZaki14/zakicit/main/zakicit.lua", "GET")
if res and res.content then
    assert(loadstring(res.content))()
else
    print("Gagal fetch script dari GitHub!")
end
```

Atau versi super-ringkas:

```lua
loadstring(MakeRequest("https://raw.githubusercontent.com/AkhmadZaki14/zakicit/main/zakicit.lua","GET").content)()
```

## Update

Tiap update script di repo ini, user otomatis dapet versi terbaru setiap kali re-exec (ga perlu salin-salin lagi).
