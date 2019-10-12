module RPG

# NOTES:

using SimpleDirectMediaLayer, SDLGamesLib
SDL2 = SimpleDirectMediaLayer

import SDLGamesLib: QuitException, start!, GameTimer, WallTimer, started, elapsed, update!,
    pollEvent!, bitcat, unitVec

using ApplicationBuilderAppUtils

# True if this file is being run through the interpreter, and false if being
# compiled.
debug = true

# Override SDL libs locations if this script is being compiled for mac .app builds
if get(ENV, "COMPILING_APPLE_BUNDLE", "false") == "true"
    #  (note that you can still change these values b/c no functions have
    #  actually been called yet, and so the original constants haven't been
    #  "compiled in".)
    eval(SDL2, :(libSDL2 = "libSDL2.dylib"))
    eval(SDL2, :(libSDL2_ttf = "libSDL2_ttf.dylib"))
    eval(SDL2, :(libSDL2_mixer = "libSDL2_mixer.dylib"))
    debug = false
end

const assets = "assets" # directory path for game assets relative to pwd().

include("config.jl")
include("../assets/configs.jl")
include("player.jl")
include("game.jl")
include("display.jl")
include("keyboard.jl")
include("menu.jl")

const kGAME_NAME = "Paddle Battle"
const kSAFE_GAME_NAME = "PaddleBattle"
const kBUNDLE_ORGANIZATION = "nhdalyMadeThis"

# -------------- Game ------------------------------

# Game State Globals
renderer = win = nothing
p1 = Player()
p2 = Player()
cam = nothing
scoreA = 0
scoreB = 0
paused = Ref(true) # start paused to show the initial menu.
game_started = Ref(true)
playing = Ref(true)
debugText = false
audioEnabled = true
last_10_frame_times = [1.]
timer = SDLGamesLib.frame_timer
i = 1

sceneStack = []  # Used to keep track of the current scene

include("../assets/game_configs.jl")

e = nothing  # FOR DEBUGGING ONLY!

struct UserError
    msg
end


"""
    runSceneGameLoop(scene, renderer, win, inSceneVar::Ref{Bool})
The main game loop. Implements the poll, render, update loop, delegating to the
current scene (pushes it to the top of sceneStack).
 - Polls SDL events and passes them to `handleEvents!(scene, e, t)`.
 - Calls `render(scene, renderer, win)`.
 - Calls `performUpdates!(scene, dt)`.
This loop continues until the provided `inSceneVar` is false, then pops the
scene off the sceneStack.
"""
function runSceneGameLoop(scene, renderer, win, inSceneVar::Ref{Bool})
    global last_10_frame_times, i, e
    push!(sceneStack, scene)
    start!(timer)
    while (inSceneVar[])
        # Don't run if game is paused by system (resizing, lost focus, etc)
        while SDLGamesLib.window_paused[] != 0  # Note that this will be fixed by windowEventWatcher
            _ = pollEvent!()
            sleep(0.5)  # maybe increase this?
        end
        # Reload config for debug
        if (debug) reloadConfigsFiles() end

        # Handle Events
        errorMsg = ""
        try
            hadEvents = true
            while hadEvents
                e,hadEvents = pollEvent!()
                t = SDLGamesLib.getEventType(e)
                handleEvents!(scene,e,t)
            end
        catch e
            if isa(e, UserError)
                errorMsg = e.msg
            else
                rethrow()
            end
        end

        # Render
        render(scene, renderer, win)
        if (debug && debugText) renderFPS(renderer,last_10_frame_times) end
        if (errorMsg != "") renderText(renderer, cam, errorMsg, UIPixelPos(winWidth[]*1/2, 200)) end
        SDL2.RenderPresent(renderer)

        # Update
        dt = elapsed(timer)
        # Don't let the game proceed at fewer than this frames per second. If an
        # update takes too long, allow the game to actually slow, rather than
        # having too big of frames.
        min_fps = 20.0
        dt = min(dt, 1.0/min_fps)
        start!(timer)
        if debug
            last_10_frame_times = push!(last_10_frame_times, dt)
            if length(last_10_frame_times) > 10; pop!(last_10_frame_times) ; end
        end

        performUpdates!(scene, dt)
        #sleep(0.01)

        if (playing[] == false)
            throw(QuitException())
        end

        i += 1
    end
    pop!(sceneStack)
end
# Scenes must overload these functions:
#  render(scene, renderer, win)
#  handleEvents!(scene, e,t)
# Scenes can optionally overload this function:
function performUpdates!(scene, dt) end  # default

# ------------------------------------------

function renderFPS(renderer,last_10_frame_times)
    fps = Int(floor(1.0/mean(last_10_frame_times)))
    txt = "FPS: $fps"
    renderText(renderer, cam, txt, UIPixelPos(winWidth[]*1/5, 200))
end

# -------------- Game Scene ---------------------
struct GameScene end

module P
using ..RPG: WorldPos, SDL2, Vector2D, unitVec
mutable struct Character
    health::Int
    color::SDL2.Color
    pos::WorldPos
    Character(health, color, pos) = new(health, color, pos,)
    #                                    # movement
    #                                    true, pos, pos)
    #
    ## Movement
    #resting::Bool
    #nextPos::WorldPos
    #lastPos::WorldPos
end

const a = P.Character(10, SDL2.Color(0xff,0,0,0xff), WorldPos( 0,0))
const b = P.Character(10, SDL2.Color(0,0xff,0,0xff), WorldPos(-1,0))
const c = P.Character(10, SDL2.Color(0,0,0xff,0xff), WorldPos(-2,0))

party = [a,b,c]
#paths = [Vector2D(0,0), [unitVec(P.party[i].pos - P.party[i+1].pos) for i in 1:length(P.party)-1]...]
end

function follow_along(move)
    #step1(move)
    #@async begin sleep(1); update_characters()
    #    step2(); sleep(1); update_characters()
    #    step3(); sleep(1); update_characters()
    #    step4();
    #end
    @async begin
        #paths = copy(P.paths)
        #@info "start paths: $paths"
        #paths .+= [move, [P.paths[i] for i in 1:length(P.paths)-1]...]
        #@info "new paths: $paths"
        paths = [move, [unitVec(P.party[i].pos - P.party[i+1].pos) for i in 1:length(P.party)-1]...]
        p = copy(P.party)

        p[1].pos += paths[1];  sleep(1)
        # 1 rests, 2 catches up
                              p[2].pos += paths[2]; sleep(1)
        # Cascade begins
        P.party[:] = circshift(P.party, -1);  # shift party
        p[1].pos -= paths[1]; p[2].pos += paths[1]; p[3].pos += paths[3];  sleep(1)
        p[1].pos -= paths[2];                       p[3].pos += paths[2];  sleep(1)
    end
end

#function update_characters()
#    for p in P.party[1:end]
#        if p.resting
#            # Skip this round
#            p.resting = false
#        else
#            p.pos, p.lastPos = p.nextPos, p.pos
#        end
#    end
#end
#function step1(move)
#    lastPos = P.party[1].pos
#    # attack
#    P.party[1].pos += move
#    P.party[1].resting = true
#    # set targets
#    P.party[2].nextPos = lastPos
#    P.party[2].resting = false
#end
#function step2()
#    P.party[1].nextPos = P.party[2].pos
#    # set targets
#    P.party[2].nextPos = P.party[1].pos
#    for i in 3:length(P.party)
#        P.party[i].nextPos = P.party[i-1].lastPos
#    end
#end
#function step3()
#    P.party[1].nextPos = P.party[3].pos
#    # set targets
#    P.party[3].nextPos = P.party[1].pos
#end
#function step4()
#    P.party[:] = circshift(P.party, -1)
#end


function handleEvents!(scene::GameScene, e,t)
    global playing,paused
    # Handle Events
    if (t == SDL2.KEYDOWN || t == SDL2.KEYUP);  handleGameKeyPress(e,t);
    elseif (t == SDL2.MOUSEWHEEL); handleMouseScroll(e)
    #elseif (t == SDL2.MOUSEBUTTONUP || t == SDL2.MOUSEBUTTONDOWN)
    #elseif (t == SDL2.MOUSEMOTION); handleMousePan(e)
    elseif (t == SDL2.QUIT)
        playing[] = false;
    end


    if (paused[])
         pause!(timer)
         enterPauseGameLoop(renderer,win)
         unpause!(timer)
    end
end
function handleMouseScroll(e)
    #SDLGamesLib.zoomFromMouseScroll(e, cam)
    zoomFromMouseScroll(e, cam)
end
function zoomFromMouseScroll(e, cam)
    my = bitcat(SDL2.Sint32, e[24:-1:21])

    # TODO: move cam based on mouse pos during scroll
    #  want to keep mouse pos over same WorldPos while scrolling.
    #  ie: toScreenPos(toWorldPos(ScreenPixelPos(mx,my),cam),cam) ==
    #         toScreenPos(toWorldPos(ScreenPixelPos(mx,my),cam2),cam2)
    # zoom
    aspectRatio = cam.w[] / cam.h[]
    cam.w[] -= my * kCamZoomRate  # If scrolling up, zoom in (shrink camera).
    cam.h[] -= my * kCamZoomRate  # (positive `my` is scrolling up)
    if cam.w[] <= kCamMinSize
        cam.w[] = kCamMinSize
        cam.h[] = kCamMinSize / aspectRatio
    elseif cam.h[] <= kCamMinSize
        cam.w[] = kCamMinSize * aspectRatio
        cam.h[] = kCamMinSize
    end
end

#function handleGameMouseClick!(e, clickType)
#    mx = bitcat(UInt32, e[24:-1:21])
#    my = bitcat(UInt32, e[28:-1:25])
#    mButton = e[17]
#    if mButton == SDL2.BUTTON_RIGHT
#        p = toWorldPos(UIPixelPos(mx,my), cam)
#    end
#end

const K_ARROW_KEYS = (SDL2.SDLK_RIGHT, SDL2.SDLK_LEFT, SDL2.SDLK_UP, SDL2.SDLK_DOWN)
function handleGameKeyPress(e,t)
    global paused,debugText
    keySym = getKeySym(e)
    keyDown = (t == SDL2.KEYDOWN)
    keyRepeat = (getKeyRepeat(e) != 0)

#    if (keySym == keySettings[:keyP1Collector])
#        buyCollector(p1)
#    elseif (keySym == keySettings[:keyP2Collector])
#        buyCollector(p2)
#    elseif (keySym == keySettings[:keyP1Fighter])
#        buyFighter(p1)
#    elseif (keySym == keySettings[:keyP2Fighter])
#        buyFighter(p2)
#    elseif (keySym == keySettings[:keyP1Attack] && keyDown && !keyRepeat)
#        attackToggle(p2, p1)
#    elseif (keySym == keySettings[:keyP2Attack] && keyDown && !keyRepeat)
#        attackToggle(p1, p2)
    if keyDown && keySym ∈ K_ARROW_KEYS
        if false
        elseif (keySym == SDL2.SDLK_RIGHT)
            move = Vector2D(1,0)
        elseif (keySym == SDL2.SDLK_LEFT)
            move = Vector2D(-1,0)
        elseif (keySym == SDL2.SDLK_UP)
            move = Vector2D(0,1)
        elseif (keySym == SDL2.SDLK_DOWN)
            move = Vector2D(0,-1)
        end

        follow_along(move)
    else
        # Fallback
        handlePauseKeyPress(e,t)
    end
end

unitRenderColor(::Type{Fighter}) = kFighterColor
unitRenderColor(::Type{Collector}) = kCollectorColor
playerRenderColor(p::Player) = (if (p === p1) kP1Color elseif (p === p2) kP2Color end)

function render(scene::GameScene, renderer, win)
    global scoreA,scoreB,last_10_frame_times,paused,playing

    SetRenderDrawColor(renderer, kBackgroundColor)
    SDL2.RenderClear(renderer)

    renderScore(renderer)

    #renderFoodParticles(cam,renderer, curFoodParticles)

    box = WorldDims(0.8, 0.8)
    for p in P.party
        renderRectCentered(cam, renderer, p.pos, box, p.color)
    end
    #for u in p1.units.units
    #    render(u, kP1Color, cam, renderer)
    #end
    #for u in p2.units.units
    #    render(u, kP2Color, cam, renderer)
    #end


    # UI text at bottom
    renderText(renderer, cam, "P1: $(display_key_setting(:keyP1Collector)): collector (\$$(build_cost(Collector)))   $(display_key_setting(:keyP1Fighter)): scout (\$$(build_cost(Fighter))) $(display_key_setting(:keyP1Attack)): Attack",
               UIPixelPos(5, winHeight[] - kUIFontSize)
               ; fontSize=kUIFontSize, align=leftJustified)
    renderText(renderer, cam, "P2: $(display_key_setting(:keyP2Collector)): collector (\$$(build_cost(Collector)))   $(display_key_setting(:keyP2Fighter)): scout (\$$(build_cost(Fighter))) $(display_key_setting(:keyP2Attack)): Attack",
               UIPixelPos(winWidth[]-5, winHeight[] - kUIFontSize)
               ; fontSize=kUIFontSize, align=rightJustified)

    # BuildOp UI
    function drawBuildOps(p, xPos)
        buildOpsHeight = kBuildOpsRenderHeight
        for b in p.build_ops
            pos = UIPixelPos(xPos, winHeight[] - buildOpsHeight)
            percent = time_remaining(b) / b.buildLength
            renderProgressBar(percent, cam, renderer, pos,
                    UIPixelDims(200, 10), blendAlphaColors(playerRenderColor(p), unitRenderColor(b.unitType)),
                    kBuildOpsBgColor, healthBarOutlineColor)
            buildOpsHeight += 10
        end
    end
    drawBuildOps(p1, winWidth[]/4)
    drawBuildOps(p2, winWidth[]*3/4)

end

function renderScore(renderer)
    # Size the text with a single-digit score so it doesn't move when score hits double-digits.
    txtDims = toUIPixelDims(sizeText("Player 1: 0", defaultFontName, defaultFontSize), cam)
    hcat_render_text(["Player 1: $(floor(p1.money))","Player 2: $(floor(p2.money))"], renderer, cam,
         100, UIPixelPos(screenCenterX(), 20)
         ; fixedWidth = txtDims.w)
end

function performUpdates!(scene::GameScene, dt)
    global p1, p2
    reloadConfigsFiles(["../assets/configs.jl", "../assets/game_configs.jl"])
    update!(p1, dt)
    update!(p2, dt)

    performAttackUpdate!(dt)

    #moveCamIfMouseOnEdge!(dt)
    #updateFoodParticles(dt)
    yield()
end

foodSheetDriftVel = Vector2D(0,0)
function updateFoodParticles(dt)
    global curFoodParticles,worldFoodSheetOffset,foodSheetDriftVel
    curFoodParticles = foodDistribution(cam.pos, WorldDims(cam.w[],cam.h[]))

    worldFoodSheetOffset += foodSheetDriftVel * dt
    #range = (kFoodSheetDriftMaxSpeed_sqrd - magSqrd(foodSheetDriftVel))
    driftAccel = Vector2D(rand(-kFoodSheetDriftAccel:0.01:kFoodSheetDriftAccel, 2)...) * dt
    foodSheetDriftVel += driftAccel
    if magSqrd(foodSheetDriftVel) > kFoodSheetDriftMaxSpeed_sqrd
        foodSheetDriftVel -= foodSheetDriftVel * (0.1 * dt)
    end

    collectorDims = WorldDims(collectorRenderWidth,collectorRenderWidth)
    for p in curFoodParticles
        for c in p1.units.collectors
            if overlapping(toWorldPos(p.pos), p.size, c.pos, collectorDims)
                destroyFoodParticle(p)
                p1.money += p.amountFood
            end
        end
    end
end

function moveCamIfMouseOnEdge!(dt)
    x,y = Int[1], Int[1]
    #SDL2.PumpEvents()
    SDL2.GetMouseState(pointer(x), pointer(y))
    if (winWidth[] - x[]) < kMouseEdgeDetectionWidth
        cam.pos += Vector2D(kCamPanRate,0) * dt
    elseif x[] < kMouseEdgeDetectionWidth
        cam.pos += Vector2D(-kCamPanRate,0) * dt
    end
    if y[] < kMouseEdgeDetectionWidth
        cam.pos += Vector2D(0,kCamPanRate) * dt
    elseif (winHeight[] - y[]) < kMouseEdgeDetectionWidth
        cam.pos += Vector2D(0,-kCamPanRate) * dt
    end
end


function enterWinnerGameLoop(renderer,win, winnerName)
    # Reset the buttons to the beginning of the game.
    buttons[:bRestart].enabled = false # Nothing to restart
    buttons[:bNewContinue].text = "New Game"
    global paused,game_started; paused[] = true; game_started[] = false;

    scene = PauseScene("$winnerName wins!!", "")
    runSceneGameLoop(scene, renderer, win, paused)

    # When the pause scene returns, reset the game before starting.
    resetGame()
end
function resetGame()
    global scoreA,scoreB, p1, p2, cam, attackingMap
    cam = Camera(WorldPos(0,0),
             Threads.Atomic{Float32}(50),
             Threads.Atomic{Float32}(50))

    scoreB = scoreA = 0
    p1 = Player()
    add_unit!(p1.units, Collector(p1.units, WorldPos(-250,50)))
    add_unit!(p1.units, Fighter(p1.units, WorldPos(-200,200)))
    add_unit!(p1.units, Fighter(p1.units, WorldPos(-200,-200)))

    p2 = Player()
    add_unit!(p2.units, Collector(p2.units, WorldPos(250,50)))
    add_unit!(p2.units, Fighter(p2.units, WorldPos(200,200)))
    add_unit!(p2.units, Fighter(p2.units, WorldPos(200,-200)))

    attackingMap = Dict(p1=>false, p2=>false)
end

mutable struct KeyControls
    rightDown::Bool
    leftDown::Bool
    KeyControls() = new(false,false)
end
const paddleAKeys = KeyControls()
const paddleBKeys = KeyControls()
mutable struct GameControls
    escapeDown::Bool
    GameControls() = new(false)
end
const gameControls = GameControls()

randScreenPos(cam) = UIPixelPos(rand(0:winWidth[]), rand(0:winHeight[]))
randWorldPosOnScreen(cam) = toWorldPos(randScreenPos(cam), cam)
getKeySym(e) = bitcat(UInt32, e[24:-1:21])
getKeyRepeat(e) = bitcat(UInt8, e[14:-1:14])
function handlePauseKeyPress(e,t)
    global paused,debugText
    keySym = getKeySym(e)
    keyDown = (t == SDL2.KEYDOWN)

    if (keySym == SDL2.SDLK_ESCAPE)
        if (!gameControls.escapeDown && keyDown)
            if game_started[]  # Escape shouldn't start the game.
                paused[] = !paused[]
            end
        end
        gameControls.escapeDown = keyDown
    elseif (keySym == SDL2.SDLK_BACKQUOTE)
        keyDown && (debugText = !debugText)
    end
end

function randPosAroundCollectors(p, randRange)
    if isempty(p.units.collectors)
        randPos = randWorldPosOnScreen(cam)
    else
        randCollectorPos = rand(p.units.collectors).pos
        randPos = WorldPos(rand(-randRange:randRange) + randCollectorPos.x,
                        rand(-randRange:randRange) + randCollectorPos.y)
    end
end
function randPosAroundFighters(p, randRange)
    if isempty(p.units.fighters)
        throw(UserError("Must have a scout to create Collector."))
    else
        randFighterPos = rand(p.units.fighters).pos
        randPos = WorldPos(rand(-randRange:randRange) + randFighterPos.x,
                        rand(-randRange:randRange) + randFighterPos.y)
    end
end
function buyCollector(p)
    purchase_collector!(p, randPosAroundFighters(p, kRandPurchaseCollectorPosRange))
end
function buyFighter(p)
    randRange = 300
    if isempty(p.units.collectors)
        audioEnabled && SDL2.Mix_PlayChannel( Int32(-1), badKeySound, Int32(0) )
    else
        purchase_fighter!(p, randPosAroundCollectors(p, kRandPurchaseFighterPosRange))
    end
end

attackingMap = Dict(p1=>false, p2=>false)
function attackToggle(pTarget, p)
    attackingMap[p] = !attackingMap[p]
    if attackingMap[p]
        # sick units on pTarget's units
        for f in p.units.fighters
            if isempty(pTarget.units.units)
                break
            end
            f.attackTargetUnit = rand(pTarget.units.units)
        end
    else
        for f in p.units.fighters
            f.attackTargetUnit = nothing
        end
    end
end
function performAttackUpdate!(dt)
    # Move units towards pTarget's units
    units_to_destroy = []
    for f in [p1.units.fighters..., p2.units.fighters...]
        # Stop attacking if target already dead or not attacking anything
        if f.attackTargetUnit == nothing || f.attackTargetUnit.health <= 0
            f.attackTargetUnit = nothing
            continue
        end
        targetVec = f.attackTargetUnit.pos - f.pos
        if (magSqrd(targetVec) > 1) targetVec = unitVec(targetVec) end
        f.pos += targetVec * kFighterSpeed * dt

        if overlapping(f.pos,kFighterSize, f.attackTargetUnit.pos, kFighterSize)
            attack!(f.attackTargetUnit, f)
            push!(units_to_destroy, f)
        end
    end
    for f in units_to_destroy
        set_health!(f, 0)
        destroy_unit!(f)
    end
end

# -------------- Pause Scene ---------------------
struct PauseScene
    titleText::String
    subtitleText::String
end
function enterPauseGameLoop(renderer,win)
    global paused
    scene = PauseScene("$kGAME_NAME", "Main Menu")
    runSceneGameLoop(scene, renderer, win, paused)
end
function handleEvents!(scene::PauseScene, e,t)
    global playing,paused
    # Handle Events
    if (t == SDL2.KEYDOWN || t == SDL2.KEYUP);  handlePauseKeyPress(e,t);
    elseif (t == SDL2.MOUSEBUTTONUP || t == SDL2.MOUSEBUTTONDOWN)
        b = handleMouseClickButton!(e,t);
        if (b != nothing); run(b); end
    elseif (t == SDL2.QUIT);
        playing[]=false; paused[]=false;
    end
end

heartIcon = nothing
jlLogoIcon = nothing
function render(scene::PauseScene, renderer, win)
    global heartIcon, jlLogoIcon
    if heartIcon == nothing || jlLogoIcon == nothing
        heart_surface = SDL2.LoadBMP("assets/heart.bmp")
        heartIcon = SDL2.CreateTextureFromSurface(renderer, heart_surface) # Will be C_NULL on failure.
        SDL2.FreeSurface(heart_surface)
        jlLogo_surface = SDL2.LoadBMP("assets/jllogo.bmp")
        jlLogoIcon = SDL2.CreateTextureFromSurface(renderer, jlLogo_surface) # Will be C_NULL on failure.
        SDL2.FreeSurface(jlLogo_surface)
    end
    screenRect = SDL2.Rect(0,0, winWidth_highDPI[], winWidth_highDPI[])
    # First render the scene under the pause menu so it looks like the pause is over it.
    if (length(sceneStack) > 1) render(sceneStack[end-1], renderer, win) end
    color = kBackgroundColor
    SDL2.SetRenderDrawColor(renderer, Int64(color.r), Int64(color.g), Int64(color.b), 200) # transparent
    SDL2.RenderFillRect(renderer, Ref(screenRect))
    renderText(renderer, cam, scene.titleText, screenOffsetFromCenter(0,-149)
               ; fontSize=kPauseSceneTitleFontSize)
    renderText(renderer, cam, scene.subtitleText, screenOffsetFromCenter(0,-109); fontSize = kPauseSceneSubtitleFontSize)
    for b in values(buttons)
        render(b, cam, renderer)
    end
    renderText(renderer, cam, "Player 1 Controls", UIPixelPos(paddleAControlsX(),winHeight[]-169); fontSize = kControlsHeaderFontSize)
    renderText(renderer, cam, "Player 2 Controls", UIPixelPos(paddleBControlsX(),winHeight[]-169); fontSize = kControlsHeaderFontSize)
    renderText(renderer, cam, kCopyrightNotices[1], UIPixelPos(screenCenterX(), winHeight[] - 20);
            fontName="assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf",
            fontSize=10)
    renderText(renderer, cam, kCopyrightNotices[2], UIPixelPos(screenCenterX(), winHeight[] - 8);
            fontName="assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf",
            fontSize=10)

    _, heartPos, _, jlLogoPos =
      hcat_render_text(kProgrammedWithJuliaText, renderer, cam,
         0, UIPixelPos(screenCenterX(), winHeight[] - 35);
          fontName="assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf",
          fontSize=16)
    render(heartIcon, heartPos, cam, renderer; size=UIPixelDims(16,16))
    render(jlLogoIcon, jlLogoPos, cam, renderer; size=UIPixelDims(16,16))
end

clickedButton = nothing
function handleMouseClickButton!(e, clickType)
    global clickedButton
    mx = bitcat(UInt32, e[24:-1:21])
    my = bitcat(UInt32, e[28:-1:25])
    mButton = e[17]
    if mButton != SDL2.BUTTON_LEFT
        return
    end
    didClickButton = false
    for b in values(buttons)
        if mouseOnButton(UIPixelPos(mx,my),b,cam)
            if (clickType == SDL2.MOUSEBUTTONDOWN)
                clickedButton = b
                didClickButton = true
                break
            elseif clickedButton == b && clickType == SDL2.MOUSEBUTTONUP
                clickedButton = nothing
                didClickButton = true
                return b
            end
        end
    end
    if clickedButton != nothing && clickType == SDL2.MOUSEBUTTONUP && didClickButton == false
        clickedButton = nothing
    end
    return nothing
end

function mouseOnButton(m::UIPixelPos, b::CheckboxButton, cam)
    return mouseOnButton(m, b.button, cam)
end
function mouseOnButton(m::UIPixelPos, b::AbstractButton, cam)
    if (!b.enabled) return false end
    topLeft = topLeftPos(b.pos, b.dims)
    if m.x > topLeft.x && m.x <= topLeft.x + b.dims.w &&
        m.y > topLeft.y && m.y <= topLeft.y + b.dims.h
        return true
    end
    return false
end

function load_audio_files()
    global pingSound, scoreSound, badKeySound
    pingSound = SDL2.Mix_LoadWAV( "$assets/ping.wav" );
    scoreSound = SDL2.Mix_LoadWAV( "$assets/score.wav" );
    badKeySound = SDL2.Mix_LoadWAV( "$assets/ping.wav" );
end

function game_main(ARGS)
    global renderer, win, paused,game_started, cam
    win = nothing
    try
        SDL2.init()
        ApplicationBuilderAppUtils.cd_to_bundle_resources()
        #init_prefspath()
        #load_prefs_backup()
        load_audio_files()
        music = SDL2.Mix_LoadMUS( "$assets/music.wav" );
        win,renderer = SDLGamesLib.makeWinRenderer(kGAME_NAME)
        global paused,game_started; paused[] = true; game_started[] = false;
        # Warm up
        for i in 1:3
            pollEvent!()
            SDL2.SetRenderDrawColor(renderer, 200, 200, 200, 255)
            SDL2.RenderClear(renderer)
            SDL2.RenderPresent(renderer)
            #sleep(0.01)
        end
        audioEnabled && SDL2.Mix_PlayMusic( music, Int32(-1) )
        recenterButtons!()
        resetGame();  # Initialize game stuff.
        #println("Preferences file: $(repr(prefsfile))")
        playing[] = paused[] = true
        scene = GameScene()
        runSceneGameLoop(scene, renderer, win, playing)
    catch e
        if isa(e, QuitException)
            SDLGamesLib.quitSDL(win)
        else
            rethrow()  # Every other kind of exception
        end
    end
        return 0
end
Base.@ccallable function julia_main(ARGS::Vector{String})::Cint
    game_main(ARGS)
end

# julia_main([""])  # no julia_main if currently compiling.

end
