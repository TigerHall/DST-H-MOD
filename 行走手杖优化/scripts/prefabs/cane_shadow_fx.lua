--------------------------------------------------------------------------
-- 暗影粒子特效
-- 使用官方 fx/pocketwatch.tex 纹理（Alarming Clock 同款）
-- 不需要任何自定义图片素材
--------------------------------------------------------------------------

local SPARKLE_TEXTURE = "fx/pocketwatch.tex"
local ADD_SHADER = "shaders/vfx_particle_add.ksh"

local COLOUR_ENVELOPE_NAME = "cane_shadow_colourenvelope"
local SCALE_ENVELOPE_NAME = "cane_shadow_scaleenvelope"

local assets =
{
  Asset("IMAGE", SPARKLE_TEXTURE),
  Asset("SHADER", ADD_SHADER),
}

--------------------------------------------------------------------------

local function IntColour(r, g, b, a)
  return { r / 255, g / 255, b / 255, a / 255 }
end

local function InitEnvelope()
  -- 暗影色：半透明灰黑 → 透明（Alarming Clock 同款暗色调）
  EnvelopeManager:AddColourEnvelope(
    COLOUR_ENVELOPE_NAME,
    {
      { 0,   IntColour(15, 10, 25, 180) },
      { .15, IntColour(40, 15, 60, 200) },
      { .4,  IntColour(30, 10, 50, 140) },
      { .7,  IntColour(10, 5, 20, 60) },
      { 1,   IntColour(0, 0, 0, 0) },
    }
  )

  local shadow_max_scale = .45
  EnvelopeManager:AddVector2Envelope(
    SCALE_ENVELOPE_NAME,
    {
      { 0,  { shadow_max_scale * .4, shadow_max_scale * .4 } },
      { .3, { shadow_max_scale, shadow_max_scale } },
      { .7, { shadow_max_scale * .8, shadow_max_scale * .8 } },
      { 1,  { shadow_max_scale * .3, shadow_max_scale * .3 } },
    }
  )

  InitEnvelope = nil
  IntColour = nil
end

--------------------------------------------------------------------------
local MAX_LIFETIME = 1.8

local function emit_shadow_fn(effect, sphere_emitter)
  local vx, vy, vz = .008 * UnitRand(), .015 + .005 * UnitRand(), .008 * UnitRand()
  local lifetime = MAX_LIFETIME * (.7 + UnitRand() * .3)
  local px, py, pz = sphere_emitter()

  local angle = math.random() * 360
  local uv_offset = math.random(0, 4) * .2
  local ang_vel = (UnitRand() - 1) * 6

  effect:AddRotatingParticleUV(
    0,
    lifetime,         -- lifetime
    px, py + 1.8, pz, -- position
    vx, vy, vz,       -- velocity
    angle, ang_vel,   -- angle, angular_velocity
    uv_offset, 0      -- uv offset
  )
end

local function fn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddNetwork()

  inst:AddTag("FX")

  inst.entity:SetPristine()

  inst.persists = false

  --Dedicated server does not need to spawn local particle fx
  if TheNet:IsDedicated() then
    return inst
  elseif InitEnvelope ~= nil then
    InitEnvelope()
  end

  local effect = inst.entity:AddVFXEffect()
  effect:InitEmitters(1)

  --SHADOW
  effect:SetRenderResources(0, SPARKLE_TEXTURE, ADD_SHADER)
  effect:SetRotationStatus(0, true)
  effect:SetUVFrameSize(0, .2, 1)
  effect:SetMaxNumParticles(0, 32)
  effect:SetMaxLifetime(0, MAX_LIFETIME)
  effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME)
  effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME)
  effect:SetBlendMode(0, BLENDMODE.AlphaBlended)
  effect:EnableBloomPass(0, false)
  effect:SetSortOrder(0, 0)
  effect:SetSortOffset(0, 1)
  effect:SetDragCoefficient(0, .05)

  -----------------------------------------------------

  local tick_time = TheSim:GetTickTime()

  local sparkle_desired_pps_low = 2
  local sparkle_desired_pps_high = 5
  local low_per_tick = sparkle_desired_pps_low * tick_time
  local high_per_tick = sparkle_desired_pps_high * tick_time
  local num_to_emit = 0

  local sphere_emitter = CreateSphereEmitter(.2)
  inst.last_pos = inst:GetPosition()

  EmitterManager:AddEmitter(inst, nil, function()
    local dist_moved = inst:GetPosition() - inst.last_pos
    local move = dist_moved:Length()
    move = math.clamp(move * 6, 0, 1)

    local per_tick = Lerp(low_per_tick, high_per_tick, move)

    inst.last_pos = inst:GetPosition()

    num_to_emit = num_to_emit + per_tick * math.random() * 3
    while num_to_emit > 1 do
      emit_shadow_fn(effect, sphere_emitter)
      num_to_emit = num_to_emit - 1
    end
  end)

  return inst
end

return Prefab("cane_shadow_fx", fn, assets)
