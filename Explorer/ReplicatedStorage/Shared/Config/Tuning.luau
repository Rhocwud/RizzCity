--!strict
--====================================================--
--  Script: [Tuning]
--  Location: [ReplicatedStorage/Shared/Config/]
--  Version: 1.0.2
--  Last Updated: 2025-09-07
--  Author: Rhocwud Games
--
--  Description:
--      Centralized tuning for Rizz City (edit values here, no code changes needed)
--
--====================================================--

return {
	Camera = {
		MinZoom = 10,
		MaxZoom = 15,
	},

	Movement = {
		Run = 15,
		Sprint = 30,
		AutoSprintHold = 1.25, -- seconds holding forward before sprint engages

		-- Momentum carry on slide end / slide jump
		MomentumCarryFactor = 0.9, -- fraction of current planar speed to keep
		MinCarrySpeed = 16,        -- don't carry below this
		MaxCarrySpeed = 60,        -- clamp to prevent crazy launches
	},

	Dash = {
		Charges = 3,
		Recharge = 2.0,   -- seconds per charge
		Impulse = 55,     -- stud/s burst
		Duration = 0.18,  -- seconds the LinearVelocity actuator lasts
		IFrames = 2.0,    -- placeholder: seconds of invulnerability for Parry/Evade
		EvadeLockout = 5.0, -- placeholder: seconds before Evade can trigger again
	},

	Slide = {
		ExitSpeed = 10,     -- speed you settle at as friction finishes
		FrictionTime = 0.8, -- time to decay from current speed to ExitSpeed
		MinSpeed = 16,      -- must be at least this fast to trigger slide
	},

	Wall = {
		LiftUpSpeed = 2.5,
		ReattachDelay = 0.25,
		JumpUp = 26,
		JumpAway = 28,
		MaxDuration = 1.6,
		RunSpeed = 22,
		AngleToleranceDeg = 35,
		MinEntrySpeed = 12,
		StickRadius = 2.5,
	},

	Grind = {
		SnapRadius = 3,
		YOffset = 0.5,
	},

	Teleport = {
		CastTime = 2.0,
		Cooldown = 90.0,
	},

	-- Placeholders for later (wired in Steps 2–5)
	Combat = {
		BlockCharges = 3,
		PerfectBlockReset = true,
	},

	Abilities = {
		-- Costs / cooldowns per ability will land here
	},

	Rizz = {
		HitGainLight = 3,
		HitGainHeavy = 6,
		ZoneTickGain = 20,
		DecayPerSecond = 0,
	},
}
