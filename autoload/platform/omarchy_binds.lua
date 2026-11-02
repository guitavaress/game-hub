-- Fase 14.30: lê os atalhos do Omarchy rodando a config de verdade do
-- Hyprland (~/.config/hypr/hyprland.lua) com um "hl" de mentira, que só anota
-- os atalhos. Assim os laços (workspaces 1..10), os "if" (apps pré-instalados) e
-- os hl.unbind do usuário saem certos. (Nasceu no spike da 14.24.)
--
-- O hyprctl binds -j dá a tecla e a descrição, mas não o comando (vem como
-- "__lua N"); aqui o comando sai junto.
--
-- Uso: lua omarchy_binds.lua [arquivo.lua]   (uma linha JSON por atalho)
-- Sem argumento, roda a config do usuário (hypr.hyprland); com um arquivo, roda
-- só ele (os testes usam arquivos de exemplo).
-- O "lua" é dependência do Hyprland: existe onde o Omarchy roda.

local home = os.getenv("HOME")
local omarchy = os.getenv("OMARCHY_PATH") or "/usr/share/omarchy"
local config = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
package.path = config .. "/?.lua;" .. omarchy .. "/?.lua;" .. package.path

-- Um objeto que aceita tudo: hl.window_rule(...):set_enabled(...), hl.config{...} etc.
local absorb
absorb = setmetatable({}, {
  __index = function() return absorb end,
  __call = function() return absorb end,
})

-- hl.dsp.window.close() vira {dsp = "window.close", args = {...}}.
local function dsp(path)
  return setmetatable({}, {
    __index = function(_, k) return dsp(path == "" and k or (path .. "." .. k)) end,
    __call = function(_, ...) return { dsp = path, args = { ... } } end,
  })
end

-- "SUPER + SHIFT + RETURN" → "SHIFT+SUPER+RETURN" (modificadores em ordem).
local MODS = { SUPER = true, SHIFT = true, CTRL = true, CONTROL = true, ALT = true, MOD5 = true, MOD3 = true }
local function normalize(keys)
  local mods, key = {}, ""
  for raw in keys:gmatch("[^+]+") do
    local part = raw:gsub("^%s+", ""):gsub("%s+$", "")
    local upper = part:upper()
    if upper == "CONTROL" then upper = "CTRL" end
    if MODS[upper] then mods[#mods + 1] = upper else key = part end
  end
  table.sort(mods)
  mods[#mods + 1] = key:upper()
  return table.concat(mods, "+")
end

-- Uma lista, e não um mapa: o Hyprland deixa vários atalhos na mesma tecla
-- (ALT + TAB foca a próxima E traz para a frente; F9 tem o "apertou" e o "soltou").
local binds = {}
hl = setmetatable({
  dsp = dsp(""),
  bind = function(keys, dispatcher, opts)
    binds[#binds + 1] = { id = normalize(keys), dispatcher = dispatcher, opts = opts or {} }
    return absorb
  end,
  unbind = function(keys)
    local id = normalize(keys)
    for _, b in ipairs(binds) do
      if b.id == id then b.removed = true end
    end
  end,
  define_submap = function() end, -- os atalhos dentro de submaps não contam
  on = function() return absorb end,
  timer = function() return absorb end,
  get_config = function() return nil end,
  version = function() return "0.56.2" end,
}, { __index = function() return absorb end })

local ok, err
if arg and arg[1] then
  ok, err = pcall(dofile, arg[1])
else
  ok, err = pcall(require, "hypr.hyprland")
end
if not ok then
  io.stderr:write("aviso: a config parou no meio: " .. tostring(err) .. "\n")
end

-- JSON mínimo (só texto, número, booleano, lista e tabela).
local function json(v)
  local t = type(v)
  if t == "string" then
    return '"' .. v:gsub('[%c"\\]', function(c)
      return string.format("\\u%04x", c:byte())
    end) .. '"'
  elseif t == "number" or t == "boolean" then
    return tostring(v)
  elseif t == "table" then
    if v == absorb then return "null" end
    if #v > 0 or next(v) == nil then
      local out = {}
      for _, x in ipairs(v) do out[#out + 1] = json(x) end
      return "[" .. table.concat(out, ",") .. "]"
    end
    local out = {}
    for k, x in pairs(v) do out[#out + 1] = json(tostring(k)) .. ":" .. json(x) end
    table.sort(out)
    return "{" .. table.concat(out, ",") .. "}"
  elseif t == "function" then
    return '"<função>"'
  end
  return "null"
end

for _, b in ipairs(binds) do
  if not b.removed then
    local d = b.dispatcher
    local action
    if type(d) == "table" and d.dsp == "exec_cmd" then
      action = { kind = "exec", cmd = d.args[1] }
    elseif type(d) == "table" and d.dsp then
      action = { kind = "dsp", name = d.dsp, args = d.args }
    elseif type(d) == "function" then
      action = { kind = "lua" }
    else
      action = { kind = "?" }
    end
    print(json({ keys = b.id, release = b.opts.release == true, description = b.opts.description or b.opts.desc or "", action = action,
      locked = b.opts.locked == true, ["repeat"] = b.opts.repeating == true }))
  end
end
