local GetPos, SetPos, IsValid, GetMoveType, WorldSpaceCenter, GetPhysicsObject
do
	local _obj_0 = FindMetaTable("Entity")
	GetPos, SetPos, IsValid, GetMoveType, WorldSpaceCenter, GetPhysicsObject = _obj_0.GetPos, _obj_0.SetPos, _obj_0.IsValid, _obj_0.GetMoveType, _obj_0.WorldSpaceCenter, _obj_0.GetPhysicsObject
end
local Alive, GetHullDuck, GetHull, IsPlayingTaunt
do
	local _obj_0 = FindMetaTable("Player")
	Alive, GetHullDuck, GetHull, IsPlayingTaunt = _obj_0.Alive, _obj_0.GetHullDuck, _obj_0.GetHull, _obj_0.IsPlayingTaunt
end
local SetUnpacked = FindMetaTable("Vector").SetUnpacked
local resume, yield, wait
do
	local _obj_0 = coroutine
	resume, yield, wait = _obj_0.resume, _obj_0.yield, _obj_0.wait
end
local sqrt, sin, cos, random
do
	local _obj_0 = math
	sqrt, sin, cos, random = _obj_0.sqrt, _obj_0.sin, _obj_0.cos, _obj_0.random
end
local MOVETYPE_WALK = MOVETYPE_WALK
local Iterator = player.Iterator
local TraceHull = util.TraceHull
local Run = hook.Run
local addonName = "Unknown Stuck - AntiPlayerStuck Solution"
local ustuck_enabled = CreateConVar("ustuck_enabled", "1", FCVAR_ARCHIVE, "Enable unstuck logic for players."):GetBool()
cvars.AddChangeCallback("ustuck_enabled", function(_, __, value)
	ustuck_enabled = value == "1"
end, addonName)
local phi = math.pi * (sqrt(5) - 1)
local downOffset = Vector(0, 0, -128)
local traceResult = { }
local trace = {
	collisiongroup = COLLISION_GROUP_PLAYER,
	mask = MASK_PLAYERSOLID,
	output = traceResult
}
local samples, y, theta, radius = 0, 0, 0, 0
local stuckType, mass = 0, 0
local tempVector = Vector()
local thread = coroutine.create(function()
	::start::
	if not ustuck_enabled then
		goto skipAll
	end
	for _, ply in Iterator() do
		if not IsValid(ply) then
			goto _continue_0
		end
		if ply.m_iOldStuckCollisionGroup ~= nil then
			ply:SetCollisionGroup(ply.m_iOldStuckCollisionGroup or 5)
		end
		if not Alive(ply) then
			goto _continue_0
		end
		if GetMoveType(ply) ~= MOVETYPE_WALK or IsPlayingTaunt(ply) then
			goto _continue_0
		end
		local phys = GetPhysicsObject(ply)
		if not (phys and phys:IsValid()) then
			goto _continue_0
		end
		mass = phys:GetMass()
		local start, mins, maxs = GetPos(ply), GetHullDuck(ply)
		trace.mins, trace.maxs = mins, maxs
		trace.filter = ply
		stuckType = 0
		local entity = nil
		for i = 1, 2 do
			if i == 2 then
				start, mins, maxs = WorldSpaceCenter(ply), GetHullDuck(ply)
				mins[3], maxs[3] = -maxs[3] / 2, 0
				trace.mins, trace.maxs = mins, maxs
			end
			trace.start, trace.endpos = start, start
			TraceHull(trace)
			if not traceResult.Hit then
				goto _continue_1
			end
			entity = traceResult.Entity
			if IsValid(entity) then
				if entity:IsRagdoll() then
					goto _continue_1
				end
				if entity:IsPlayer() and entity:Alive() then
					stuckType = 3
				else
					phys = GetPhysicsObject(entity)
					if phys and phys:IsValid() then
						if phys:IsMoveable() and phys:IsMotionEnabled() then
							if phys:IsPenetrating() and phys:GetMass() >= mass then
								stuckType = 2
								break
							end
						else
							stuckType = 1
							break
						end
					end
				end
			else
				stuckType = 1
				break
			end
			::_continue_1::
		end
		if Run("PlayerStuck", ply, traceResult, stuckType) == false then
			goto solved
		end
		if stuckType == 3 then
			entity.m_iOldStuckCollisionGroup = entity:GetCollisionGroup()
			entity:SetCollisionGroup(15)
			ply.m_iOldStuckCollisionGroup = ply:GetCollisionGroup()
			ply:SetCollisionGroup(15)
			SetUnpacked(tempVector, random(0, 1) == 0 and -512 or 512, random(0, 1) == 0 and -512 or 512, 128)
			ply:SetVelocity(tempVector)
			wait(0.25)
			goto solved
		end
		if stuckType == 2 then
			goto solved
		end
		if stuckType == 1 then
			mins, maxs = GetHull(ply)
			trace.mins, trace.maxs = mins, maxs
			for j = 1, 3 do
				samples = 16 * j
				for i = 0, samples do
					y, theta = 1 - (i / (samples - 1)) * 2, phi * i
					radius = sqrt(1 - y * y)
					SetUnpacked(tempVector, cos(theta) * radius, y, sin(theta) * radius)
					trace.start = start + tempVector * 128 * j
					trace.endpos = trace.start
					TraceHull(trace)
					if not traceResult.Hit then
						trace.endpos = trace.start + downOffset
						TraceHull(trace)
						SetPos(ply, traceResult.HitPos)
						stuckType = 0
						break
					end
				end
				if stuckType == 0 then
					break
				end
			end
		end
		if stuckType ~= 0 then
			local spawnPoint = Run("PlayerSelectSpawn", ply, false)
			if spawnPoint and IsValid(spawnPoint) then
				SetPos(ply, GetPos(spawnPoint))
			else
				SetPos(ply, vector_origin)
			end
		end
		::solved::
		yield()
		::_continue_0::
	end
	::skipAll::
	yield()
	goto start
end)
do
	local ok, msg = false, nil
	return timer.Create(addonName, 0.05, 0, function()
		ok, msg = resume(thread)
		if not ok then
			return ErrorNoHaltWithStack(msg)
		end
	end)
end
