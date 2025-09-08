-- SpecialIdle (ModuleScript)
-- Place this ModuleScript in StarterPlayerScripts
-- API:
--   SpecialIdle.Bind(character, opts) -> returns manager
--   manager:OnBecomeIdle()    -- call when your animate script wants to go to idle (handles chance -> special then resume default)
--   manager:PlayImmediateAnimId(id) -- play a one-shot anim (e.g., for jump special), then return to default
--   manager:Destroy() -- cleanup

local SpecialIdle = {}
SpecialIdle.__index = SpecialIdle

local function toAnimId(id)
	id = tostring(id or "")
	if id:match("^rbxassetid://") or id:match("^http") then
		return id
	else
		return "rbxassetid://" .. id
	end
end

local function weightedPick(list)
	local total = 0
	for _,v in ipairs(list) do total = total + (v.weight or 0) end
	if total <= 0 then return nil end
	local r = math.random() * total
	local cum = 0
	for _,v in ipairs(list) do
		cum = cum + (v.weight or 0)
		if r <= cum then return v.index end
	end
	return list[#list].index
end

function SpecialIdle.Bind(character, opts)
	opts = opts or {}
	local humanoid = character:WaitForChild("Humanoid")
	local animator = humanoid:WaitForChild("Animator")
	if not humanoid or not animator then
		warn("[SpecialIdle] missing humanoid/animator")
		return nil
	end

	local self = setmetatable({}, SpecialIdle)
	self.Character = character
	self.Humanoid = humanoid
	self.Animator = animator
	self.DefaultId = toAnimId(opts.default or "121641334368038")
	self.StopChance = (opts.stopChance ~= nil) and opts.stopChance or 0.20
	self.Variants = opts.variants or {} -- table of { id=..., weight=... }
	self._cooldown = opts.cooldown or 0.5 -- short guard to prevent immediate double-trigger
	self._isPlayingSpecial = false
	self._running = true

	-- prebuild Animation instances for variants
	self._variantAnims = {}
	for i,entry in ipairs(self.Variants) do
		local anim = Instance.new("Animation")
		anim.Name = "SpecialIdle_variant_"..tostring(i)
		anim.AnimationId = toAnimId(entry.id)
		self._variantAnims[i] = anim
	end

	-- default anim instance
	self._defaultAnim = Instance.new("Animation")
	self._defaultAnim.Name = "SpecialIdle_default"
	self._defaultAnim.AnimationId = self.DefaultId

	-- load default track
	self._defaultTrack = animator:LoadAnimation(self._defaultAnim)
	-- ensure default plays now so Animate's initial call can rely on already-playing default
	self._defaultTrack.Looped = true -- try to set looped; if engine supports it this helps
	self._defaultTrack:Play(0.12)

	-- build specials list (indexes + weights)
	self._specials = {}
	for i,entry in ipairs(self.Variants) do
		if toAnimId(entry.id) ~= self.DefaultId then
			table.insert(self._specials, { index = i, weight = entry.weight or 1 })
		end
	end

	-- internal guard for cooldown
	self._lastTrigger = 0

	-- returned manager methods
	function self:OnBecomeIdle()
		if not self._running then return end
		-- if already playing a special, do nothing
		if self._isPlayingSpecial then return end
		-- short cooldown guard
		if tick() - self._lastTrigger < self._cooldown then return end

		-- decide whether to roll for special
		if #self._specials > 0 and math.random() <= self.StopChance then
			-- pick by weight and play
			local pick = weightedPick(self._specials)
			if pick then
				self:_playSpecialByVariantIndex(pick)
			end
		else
			-- ensure default is playing
			if not self._defaultTrack.IsPlaying then
				self._defaultTrack:Play(0.12)
			end
		end
	end

	function self:PlayImmediateAnimId(id)
		if not self._running then return end
		-- play arbitrary anim id once, then resume default
		local asset = toAnimId(id)
		local anim = Instance.new("Animation")
		anim.AnimationId = asset
		local track = self.Animator:LoadAnimation(anim)
		-- stop default & play
		if self._defaultTrack and self._defaultTrack.IsPlaying then
			self._defaultTrack:Stop(0.1)
		end
		self._isPlayingSpecial = true
		track:Play(0.12)
		if track.Stopped then
			track.Stopped:Wait()
		else
			-- fallback duration guard (1s)
			task.wait(1)
		end
		self._isPlayingSpecial = false
		self._lastTrigger = tick()
		-- resume default
		if self._defaultTrack then
			self._defaultTrack:Play(0.12)
		end
	end

	function self:_playSpecialByVariantIndex(variantIndex)
		if not self._running then return end
		local animInst = self._variantAnims[variantIndex]
		if not animInst then return end
		local track = self.Animator:LoadAnimation(animInst)
		-- stop default & play special
		if self._defaultTrack and self._defaultTrack.IsPlaying then
			self._defaultTrack:Stop(0.08)
		end
		self._isPlayingSpecial = true
		track:Play(0.12)
		if track.Stopped then
			track.Stopped:Wait()
		else
			task.wait(1)
		end
		self._isPlayingSpecial = false
		self._lastTrigger = tick()
		-- resume default
		if self._defaultTrack then
			self._defaultTrack:Play(0.12)
		end
	end

	function self:Destroy()
		self._running = false
		if self._defaultTrack and self._defaultTrack.IsPlaying then
			self._defaultTrack:Stop(0.05)
		end
	end

	return self
end

return SpecialIdle
