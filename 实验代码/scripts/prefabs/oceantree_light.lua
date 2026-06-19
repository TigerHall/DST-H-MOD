-- 浅绿色光特效定义
local function lightfn()
  local inst = CreateEntity()

  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()
  inst.entity:AddSoundEmitter()

  inst.entity:AddLight()

  inst.Light:SetRadius(6.6)
  inst.Light:SetFalloff(0.6)
  inst.Light:SetIntensity(0.6)
  inst.Light:SetColour(0.6, 0.8, 0.6)
  inst.Light:Enable(true)

  inst:AddTag("FX")
  inst:AddTag("daylight")
  inst:AddTag("lightsource")

  inst.entity:SetPristine()

  if not TheWorld.ismastersim then
    return inst
  end

  -- inst.persists = false

  return inst
end

--发光实体
return Prefab("oceantree_light", lightfn)
