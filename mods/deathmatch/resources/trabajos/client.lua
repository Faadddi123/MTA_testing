function actualizarDashBoard()
	jugadores = getElementsByType("player",root,true)
	for num, jugador in ipairs(jugadores) do
		ocupacionActualizar = getElementData(jugador, "Ocupacion") or "Civil"
		if ocupacionActualizar:find "Minero" ~= nil then
            nivelMinero = getElementData(jugador, "nivelMinero") or 0
            setElementData(jugador,"Ocupacion", "Minero (Nivel "..nivelMinero..")", true)
        end 
	end	
end
addEventHandler("onClientRender",getRootElement(),actualizarDashBoard)