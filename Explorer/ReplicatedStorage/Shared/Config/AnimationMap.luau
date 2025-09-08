--!strict

--====================================================--
--  Script: [AnimationMap]
--  Location: [ReplicatedStorage/Shared/Config/]
--  Version: 1.0.0
--  Last Updated: 2025-09-06
--  Author: Rhocwud Games
--
--  Description:
--      This table maps animation *names* to asset IDs for R15
--
--  Change Log:
--      v1.0.0 - Initial version
--
--====================================================--

return {
    R15 = {
        -- Movement
        Idle = "rbxassetid://89270772523066",
        Run = "rbxassetid://100848839471019",
        Sprint = "rbxassetid://109015497048447",
        Walk = "rbxassetid://81635423737251",
        Jump = "rbxassetid://121901632923240",
        Fall = "rbxassetid://124787231630341",
        Land = "rbxassetid://128109770391716",

        -- Combat
        Attack_Light = "rbxassetid://75403471806623",
        Attack_Heavy = "rbxassetid://87513686930348",
        Block = "rbxassetid://92082875551446",
        Dodge = "rbxassetid://118369435372728",
        HitReact = "rbxassetid://108869292754746",
        Roll = "rbxassetid://129967246990443",
    },
}
