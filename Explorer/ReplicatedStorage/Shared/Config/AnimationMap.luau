--!strict

--====================================================--
--  Script: [AnimationMap]
--  Location: [ReplicatedStorage/Shared/Config/]
--  Version: 1.0.0
--  Last Updated: 2025-09-06
--  Author: Rhocwud Games
--
--  Description:
--      [This table maps animation *names* to asset IDs for R15 and R6 (fallback) separately]
--
--  Change Log:
--      v1.0.0 - Initial version
--
--====================================================--

return {
	R15 = {
		-- Movement
		Idle         = "rbxassetid://89270772523066",
		Run          = "rbxassetid://100848839471019",
		Sprint       = "rbxassetid://109015497048447",
		Walk         = "rbxassetid://81635423737251",
		Jump         = "rbxassetid://121901632923240",
		Fall         = "rbxassetid://124787231630341",
		Land         = "rbxassetid://128109770391716",

		-- Combat
		Attack_Light = "rbxassetid://75403471806623",
		Attack_Heavy = "rbxassetid://87513686930348",
		Block        = "rbxassetid://92082875551446",
		Dodge        = "rbxassetid://118369435372728",
		HitReact     = "rbxassetid://108869292754746",
		Roll         = "rbxassetid://129967246990443",
	},

	R6 = {
		-- Movement
		Idle         = "rbxassetid://95119864452237",
		Run          = "rbxassetid://128168823031283",
		Sprint       = "rbxassetid://77920105701904",
		Walk         = "rbxassetid://136018241058880",
		Jump         = "rbxassetid://102700142311861",
		Fall         = "rbxassetid://133036763880387",
		Land         = "rbxassetid://113171326944663",

		-- Combat
		Attack_Light = "rbxassetid://127084132713533",
		Attack_Heavy = "rbxassetid://103087328389306",
		Block        = "rbxassetid://124616185056712",
		Dodge        = "rbxassetid://97551273230079",
		HitReact     = "rbxassetid://132739445496948",
		Roll         = "rbxassetid://118597151395122",
	}
}
