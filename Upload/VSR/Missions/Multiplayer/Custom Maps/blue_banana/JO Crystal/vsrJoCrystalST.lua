--[[

	VSR: JO CRYSTAL
	Lua Script
	Created by blue_banana

]]--

local game = {tick = 0, time = 0}

local crystal = {
	handle = nil, spawn = "crystal_sp",
	timeStart = 45, timeLeft = 0
}

function Save()
	print("SAVE")
	return game, crystal
end

function Load(resyncData, crystalData)
	print("LOAD")
	game = resyncData
	crystal = crystalData
end

function Start()
	print("START")
end

function Update()

	-- GAME TICK UPDATE
	game.tick = game.tick + 1

-- GAME TIME UPDATE
	if game.tick % 20 == 1 then
		game.time = game.time + 1
		--print("SECOND "..game.time)

		-- CRYSTAL SIMULATION
		if IsValid(crystal.handle) then
			Stop(crystal.handle, 1)
		-- CRYSTAL RESPAWN
		else
			crystal.timeLeft = crystal.timeLeft - 1
			if crystal.timeLeft <= 0 then
				print("Respawning Crystal")
				crystal.handle = BuildObject("bvcrystalvcs", 0, crystal.spawn, 0)
				crystal.timeLeft = crystal.timeStart
			end
		end

	end
end