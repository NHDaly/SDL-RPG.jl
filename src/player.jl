include("units.jl")
import Base.show

struct BuildOp
    unitBuildFunc
    unitType # needed for rendering
    buildLength::Number
    timer::GameTimer
    BuildOp(unitBuildFunc, unitType, buildLength) = new(unitBuildFunc, unitType, buildLength, GameTimer())
end
time_remaining(bop::BuildOp) = bop.buildLength - elapsed(bop.timer)
Base.show(io::IO, bop::BuildOp) = print(io, "BuildOp($(bop.unitBuildFunc)() in $(round(time_remaining(bop), 2)) secs)")

mutable struct Player
    units::PlayerUnits
    money
    build_ops::Array{BuildOp}
    Player() = new(PlayerUnits(), 0, BuildOp[])
    Player(m) = new(PlayerUnits(), m, BuildOp[])

    #Player() = (self = new(0, BuildOp[]); self.units = PlayerUnits(self))
    #Player(m) = (self = new(m, BuildOp[]); self.units = PlayerUnits(self))
end

function update!(p::Player, dt)
    p.money += length(p.units.collectors) * kMoneyPersecPercollector * dt

    for bop in p.build_ops
        update!(bop.timer, dt)
        if (time_remaining(bop) < 0)
            bop.unitBuildFunc()
        end
    end
    # Remove the completed build ops.
    filter!(bop->time_remaining(bop)>0, p.build_ops)
end

function purchase_unit!(p::Player, unitType::Type, addUnitFunc)
    if p.money < build_cost(unitType)
        return
    end
    p.money -= build_cost(unitType)
    bop = BuildOp(addUnitFunc, unitType, build_time(unitType))
    push!(p.build_ops, bop)
    start!(bop.timer)
    sort!(p.build_ops; by=time_remaining)
    return (bop, p.money)
end
function purchase_collector!(p::Player, pos = WorldPos(0,0))
     purchase_unit!(p, Collector, ()->add_unit!(p.units, Collector(p.units, pos)))
 end
function purchase_fighter!(p::Player, pos = WorldPos(0,0))
     purchase_unit!(p, Fighter, ()->add_unit!(p.units, Fighter(p.units, pos)))
 end

# Tests
p = Player(20)
purchase_collector!(p)
@test 17 == p.money
purchase_fighter!(p)
purchase_collector!(p)
@test 3 == length(p.build_ops)
update!(p, 0.05)
@test 3 == length(p.build_ops)
update!(p, 100)
@test 0 == length(p.build_ops)
@test 3 == length(p.units.units)
@test 2 == length(p.units.collectors)
# kill unit
try
    while true
        attack!(p.units.units[1], p.units.fighters[1])
    end
catch end
@test 0 == length(p.units.units)
