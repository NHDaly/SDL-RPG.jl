module AnimTest

using RPG
using RPG.Animations: Animation, loopanim_callback
using RPG: UIPixelPos, Camera

using Test

# Mock out `render` function for tests
struct MockFrame
    x
end
function RPG.render(f::MockFrame, pos, camera, renderer; kwargs...)
    f.x
end

@testset "Animation render & update!" begin
    @testset "Simple animation" begin
        every_sec = Animation([MockFrame(x) for x in 1:3], [1,1,1])
        @test 1 == RPG.render(every_sec, UIPixelPos(0,0), Camera(), nothing; size=1)

        # After 0.5 secs, still on first frame
        RPG.update!(every_sec, 0.5)
        @test 1 == RPG.render(every_sec, UIPixelPos(0,0), Camera(), nothing; size=1)

        # After 0.6 secs, into the second frame
        RPG.update!(every_sec, 0.6)
        @test 2 == RPG.render(every_sec, UIPixelPos(0,0), Camera(), nothing; size=1)

        # At *exactly* 3 seconds, onto the third frame  (from the `>=` in update!)
        RPG.update!(every_sec, 0.9)
        @test 3 == RPG.render(every_sec, UIPixelPos(0,0), Camera(), nothing; size=1)

        # After all subsequent updates, it's still emitting the last frame.
        RPG.update!(every_sec, 2)
        @test 3 == RPG.render(every_sec, UIPixelPos(0,0), Camera(), nothing; size=1)
    end

    @testset "skip frames" begin
        a = Animation([MockFrame(x) for x in 1:10], ones(10))
        RPG.update!(a, 1)  # start with an update
        @test 2 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        RPG.update!(a, 5)  # skip frames
        @test 7 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        RPG.update!(a, 5)  # skip past end (10)
        @test 10 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
    end

    @testset "variable timings" begin
        a = Animation([MockFrame(x) for x in 1:3], [1, 10, 1])
        @test 1 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        RPG.update!(a, 1)
        @test 2 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        RPG.update!(a, 1)
        @test 2 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        RPG.update!(a, 9)
        @test 3 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
    end
end

@testset "Animation donecallback" begin
    let _rem_dt = nothing
        _test_callback(a, rem_dt) = (_rem_dt = rem_dt)

        a = Animation([MockFrame(x) for x in 1:2], [1,1], _test_callback)
        # During last frame, callback hasn't triggered
        RPG.update!(a, 1)
        @test 2 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        @test _rem_dt == nothing

        # After finishing last frame, callback triggered.
        RPG.update!(a, 1)  # Jumping _exactly_, so no remainder
        @test 2 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        @test _rem_dt == 0

        # Now, further updates don't trigger the callback
        _test_callback(nothing, nothing)  # Reset
        RPG.update!(a, 1)  # Ignored
        @test 2 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        @test _rem_dt == nothing
    end

    let _rem_dt = nothing
        _test_callback(a, rem_dt) = (_rem_dt = rem_dt)

        # Jumping _over_ the last frame sets a remainder
        a = Animation([MockFrame(x) for x in 1:2], [1,1], _test_callback)
        RPG.update!(a, 2.5)
        @test 2 == RPG.render(a, UIPixelPos(0,0), Camera(), nothing; size=1)
        @test _rem_dt == 0.5
    end
end

@testset "looping" begin
    looping = Animation([MockFrame(x) for x in 1:3], [1,1,1], loopanim_callback)
    # Jump to last frame
    RPG.update!(looping, 2)
    @test 3 == RPG.render(looping, UIPixelPos(0,0), Camera(), nothing; size=1)

    # After finishing the last frame, it loops back to the beginning
    RPG.update!(looping, 1)
    @test 1 == RPG.render(looping, UIPixelPos(0,0), Camera(), nothing; size=1)

    # updates longer than the entire animation wrap
    RPG.update!(looping, 3)
    @test 1 == RPG.render(looping, UIPixelPos(0,0), Camera(), nothing; size=1)
    RPG.update!(looping, 5)
    @test 3 == RPG.render(looping, UIPixelPos(0,0), Camera(), nothing; size=1)
end

end
