-- 制图桌回收：已擦除解锁配方记录（世界级持久化）
-- 只存配方名集合，写入即视为已解锁。
-- 新玩家加入时遍历全部解锁配方，调用 builder:UnlockRecipe 同步。

local HModCartoErased = Class(function(self, inst)
    self.inst = inst
    self.unlocked = {}       -- { [rname] = true }
end)

function HModCartoErased:Unlock(rname)
    self.unlocked[rname] = true
end

function HModCartoErased:HasEntry(rname)
    return self.unlocked[rname] == true
end

function HModCartoErased:GetAllUnlocked()
    return self.unlocked
end

function HModCartoErased:OnSave()
    return { unlocked = self.unlocked }
end

function HModCartoErased:OnLoad(data)
    if data and data.unlocked then
        self.unlocked = data.unlocked
    end
end

return HModCartoErased
