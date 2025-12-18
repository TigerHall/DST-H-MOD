-- 浅绿色光特效定义
local function lightfn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddLight()
  inst.entity:AddNetwork()
  -- 让作物生长
  inst:AddTag("daylight")
  inst:AddTag("FX")

  local light_radius = TUNING.hcanelight or 6
  inst.Light:SetRadius(light_radius)
  inst.Light:SetFalloff(0.6)
  inst.Light:SetIntensity(0.6)
  inst.Light:SetColour(0.6, 0.8, 0.6)
  inst.Light:Enable(true)

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  inst.persists = false

  return inst
end

--发光实体
return Prefab("hehu_light", lightfn)
