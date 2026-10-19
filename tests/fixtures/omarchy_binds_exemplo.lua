-- Config de exemplo para o tests/check_omarchy_binds.gd: o leitor roda este
-- arquivo com um "hl" de mentira e anota os atalhos.
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd("omarchy-launch-terminal"), { description = "Terminal" })
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("omarchy-menu toggle"), { description = "Omarchy menu" })
hl.bind("SHIFT + SUPER + B", hl.dsp.exec_cmd("omarchy-launch-webapp https://exemplo.org"), { description = "Webapp" })
hl.bind("SUPER + W", hl.dsp.window.close(), { description = "Fechar" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + LEFT", hl.dsp.focus({ direction = "l" }))
-- Um laço, como o dos workspaces do Omarchy: SUPER + 1..3 e SUPER + SHIFT + 1..3.
for i = 1, 3 do
  hl.bind("SUPER + code:" .. (9 + i), hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind("SUPER + SHIFT + code:" .. (9 + i), hl.dsp.window.move({ workspace = tostring(i) }))
end
-- Duas ações na mesma tecla (o Hyprland deixa).
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())
hl.bind("ALT + TAB", hl.dsp.window.bring_to_top())
-- O usuário desfaz um atalho.
hl.bind("SUPER + X", hl.dsp.exec_cmd("comando-apagado"))
hl.unbind("SUPER + X")
-- O "soltou" não tem o que fazer no hub.
hl.bind("F9", hl.dsp.exec_cmd("so-ao-soltar"), { release = true })
-- Coisas que o hub não faz (flutuar) e uma função Lua.
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + C", function() end)
