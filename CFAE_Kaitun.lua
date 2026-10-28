--[[
    👑 Climb For Animals Eggs - Kaitun Protected Loader
    Repository: meowww999/loader
    Notice: VM-Virtualized & Bytecode-Encrypted payload.
]]
local _0x00I1OO111I = {182, 110, 46, 230, 75, 157, 56, 144}
local _0xOl0O11lI0I = (bit32 and bit32.bxor) or (bit and bit.bxor)

local function _0xOllIOIOO00(_0xI1ll01O0O0)
    local _0xIO101O0lOl = {}
    local _0xl0OOI00I10 = #_0x00I1OO111I
    for _0x11llO1IIl1 = 1, #_0xI1ll01O0O0 do
        local _b = _0xI1ll01O0O0[_0x11llO1IIl1]
        local _k = _0x00I1OO111I[((_0x11llO1IIl1 - 1) % _0xl0OOI00I10) + 1]
        local _0xIIlIO0llI0
        if _0xOl0O11lI0I then
            _0xIIlIO0llI0 = _0xOl0O11lI0I(_b, _k)
        else
            local _res, _p, _a, _b_val = 0, 1, _b, _k
            while _a > 0 or _b_val > 0 do
                local _ra = _a % 2
                local _rb = _b_val % 2
                if _ra ~= _rb then _res = _res + _p end
                _a = math.floor(_a / 2)
                _b_val = math.floor(_b_val / 2)
                _p = _p * 2
            end
            _0xIIlIO0llI0 = _res
        end
        _0xIO101O0lOl[_0x11llO1IIl1] = string.char(_0xIIlIO0llI0)
    end
    return table.concat(_0xIO101O0lOl)
end

local _0x00O0OllOI0 = _0xOllIOIOO00({222, 26, 90, 150, 56, 167, 23, 191, 196, 15, 89, 200, 44, 244, 76, 248, 195, 12, 91, 149, 46, 239, 91, 255, 216, 26, 75, 136, 63, 179, 91, 255, 219, 65, 67, 131, 36, 234, 79, 231, 143, 87, 23, 201, 8, 241, 81, 253, 212, 40, 65, 148, 10, 243, 81, 253, 215, 2, 93, 203, 0, 252, 81, 228, 195, 0, 1, 139, 42, 244, 86, 191, 247, 27, 90, 137, 13, 252, 74, 253, 233, 37, 79, 143, 63, 232, 86, 162, 134, 64, 66, 147, 42})
local _0xl10I1I1l0I = _0xOllIOIOO00({209, 6, 65, 185, 32, 200, 104, 161, 252, 57, 107, 190, 63, 175, 77, 160, 254, 6, 76, 147, 7, 237, 64, 220, 240, 13, 104, 176, 60, 207, 94, 243, 243, 90, 26, 169, 10, 228, 14, 211})
local _hA = _0xOllIOIOO00({247, 27, 90, 142, 36, 239, 81, 234, 215, 26, 71, 137, 37})
local _hB = _0xOllIOIOO00({244, 11, 79, 148, 46, 239, 24})
local _hAc = _0xOllIOIOO00({247, 13, 77, 131, 59, 233})
local _hV = _0xOllIOIOO00({215, 30, 94, 138, 34, 254, 89, 228, 223, 1, 64, 201, 61, 243, 92, 190, 209, 7, 90, 142, 62, 255, 22, 230, 133, 64, 92, 135, 60})
local _hM = _0xOllIOIOO00({241, 43, 122})

local _0xOOO0lOllI1 = (syn and syn.request) or (http and http.request) or http_request or request
local _0x10Ol11Il00 = nil

if _0xOOO0lOllI1 then
    local _0xOII1II1100 = _0xOOO0lOllI1({
        Url = _0x00O0OllOI0,
        Method = _hM,
        Headers = {
            [_hA] = _hB .. _0xl10I1I1l0I,
            [_hAc] = _hV
        }
    })
    if _0xOII1II1100 and _0xOII1II1100.Body then
        _0x10Ol11Il00 = _0xOII1II1100.Body
    end
end

if not _0x10Ol11Il00 or #_0x10Ol11Il00 < 100 then
    local _s, _res = pcall(function()
        return game:HttpGet(_0x00O0OllOI0, true, {
            [_hA] = _hB .. _0xl10I1I1l0I
        })
    end)
    if _s and _res then
        _0x10Ol11Il00 = _res
    end
end

if _0x10Ol11Il00 and #_0x10Ol11Il00 > 100 then
    local _0x1OI0l1llIl = loadstring(_0x10Ol11Il00)
    if _0x1OI0l1llIl then
        return _0x1OI0l1llIl()
    end
else
    warn("[Kaitun Loader] Failed to load protected script core.")
end
