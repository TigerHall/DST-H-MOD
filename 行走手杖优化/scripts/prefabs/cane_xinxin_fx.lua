--------------------------------------------------------------------------

local function IntColour(r, g, b, a)
  return { r / 255, g / 255, b / 255, a / 255 }
end

local TEXTURE = resolvefilepath("images/fx/xin.tex")
local SHADER = "shaders/vfx_particle.ksh"

local COLOUR_ENVELOPE_NAME = "cane_xinxin_colourenvelope"
local SCALE_ENVELOPE_NAME = "cane_xinxin_scaleenvelope"

local assets =
{
  Asset("IMAGE", TEXTURE),
  Asset("SHADER", SHADER),
}

--------------------------------------------------------------------------

local function InitEnvelope()
  -- 添加颜色变化，猜测表中第一个元素是一个类似渐变或者时间的东西
  -- 比如0表示生命周期的初始，1表示100%
  -- 后面是颜色值，对应rgba，最后一个a是透明度
  EnvelopeManager:AddColourEnvelope(
    COLOUR_ENVELOPE_NAME,
    {
      { 0,   IntColour(255, 255, 255, 255) },
      { .66, IntColour(255, 255, 255, 166) },
      { 1,   IntColour(255, 255, 255, 0) },
    }
  )

  local glow_max_scale = .3
  -- 添加位置变化，与上面颜色变化一样，猜测表中第一个元素是一个类似渐变或者时间的东西
  -- 后面参数是缩放的大小了
  EnvelopeManager:AddVector2Envelope(
    SCALE_ENVELOPE_NAME,
    {
      { 0,   { glow_max_scale * 0.6, glow_max_scale * 0.6 } },
      { .66, { glow_max_scale * 1.2, glow_max_scale * 1.2 } },
      { 1,   { glow_max_scale * 1.6, glow_max_scale * 1.6 } },
    }
  )

  InitEnvelope = nil
  IntColour = nil
end

--------------------------------------------------------------------------
-- 特效存在时间
local GLOW_MAX_LIFETIME = 3.6

-- 粒子触发器里第三个参数fn里调用的方法，展示粒子大小，方向，速度，生命周期等等信息
local function emit_glow_fn(effect, emitter_fn)
  -- X左右 Y高度 Z上下
  local vx, vy, vz = 0, 0, 0
  local lifetime = GLOW_MAX_LIFETIME * (.9 + math.random() * .1)
  local px, py, pz = emitter_fn()
  -- 角度随机
  -- local uv_offset = math.random(0, 1) * .25
  effect:AddRotatingParticle(
    0,
    lifetime,         -- lifetime  生命周期
    px, py + 3.6, pz, -- position  位置
    vx, vy, vz,       -- velocity  速度
    0,                -- angle               角度
    0                 -- angle velocity           角速度
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
    InitEnvelope() -- 初始化颜色和形状变化的设置
  end

  -- 给prefab添加粒子特效
  local effect = inst.entity:AddVFXEffect()
  -- 初始化有几个触发器
  effect:InitEmitters(1)
  -- 渲染的资源，就是做的贴图与一个shader
  effect:SetRenderResources(0, TEXTURE, SHADER)
  -- 最大粒子数
  effect:SetMaxNumParticles(0, 16)
  -- 循环状态开启
  effect:SetRotationStatus(0, true)
  -- 最大生命周期
  effect:SetMaxLifetime(0, GLOW_MAX_LIFETIME)
  -- 颜色变化
  effect:SetColourEnvelope(0, COLOUR_ENVELOPE_NAME)
  -- 形状变化
  effect:SetScaleEnvelope(0, SCALE_ENVELOPE_NAME)
  -- 粒子混合模式，在 constants.lua 里有定义，有几个值，具体不清楚都什么效果
  effect:SetBlendMode(0, BLENDMODE.AlphaBlended)
  effect:EnableBloomPass(0, true)
  effect:SetSortOrder(0, 0)
  effect:SetSortOffset(0, -1)
  effect:SetKillOnEntityDeath(0, true)
  effect:SetFollowEmitter(0, true)

  -----------------------------------------------------


  local tick_time = TheSim:GetTickTime()

  -- 喷射频率
  local glow_desired_pps = 0.16
  local glow_particles_per_tick = glow_desired_pps * tick_time
  local glow_num_particles_to_emit = 0
  -- 多大范围内发射粒子
  local sphere_emitter = CreateSphereEmitter(.03)
  -- 添加粒子触发器，第三个参数是个fn，在 emitters.lua 里会被PostUpdate()重复调用
  EmitterManager:AddEmitter(inst, nil, function()
    while glow_num_particles_to_emit > 1 do
      emit_glow_fn(effect, sphere_emitter)
      glow_num_particles_to_emit = glow_num_particles_to_emit - 1
    end
    glow_num_particles_to_emit = glow_num_particles_to_emit + glow_particles_per_tick * math.random() * 3
  end)

  return inst
end

return Prefab("cane_xinxin_fx", fn, assets)
