# Defines structus and functions relating to display.
# Defines `render` for all game objects.

function renderProgressBar(percent, cam::Camera, renderer, center::AbstractPos{C}, dims::D, color, bgColor, boxColor) where D<:AbstractDims{C} where C
    # bg
    renderRectCentered(cam, renderer, center, dims, bgColor)
    # progress
    origin = topLeftPos(center, dims)
    renderRectFromOrigin(cam, renderer, origin, D(round(percent * dims.w), dims.h), color)
    # outline
    renderRectCentered(cam, renderer, center, dims, nothing; outlineColor=boxColor)
end
function renderUnit(o::UnitTypes, playerColor, cam::Camera, renderer, dims::WorldDims, color)
    # First render the player color, then the unit color (for transparency)
    renderRectCentered(cam, renderer, o.pos, dims, playerColor)
    renderRectCentered(cam, renderer, o.pos, dims, color)

    # render health bar
    healthBarPos = WorldPos(o.pos.x, o.pos.y + dims.h/2 + healthBarRenderOffset)
    healthBarDims = WorldDims(healthBarRenderWidth, healthBarRenderHeight)
    renderProgressBar(health_percent(o), cam, renderer, healthBarPos,
          healthBarDims, healthBarColor, kBuildOpsBgColor,
          if toScreenPixelDims(healthBarDims, cam).h <= 2 # pixels
              nothing
          else
              healthBarOutlineColor
          end)
end
function render(o::Collector, playerColor, cam::Camera, renderer)
    unitColor = blendAlphaColors(playerColor, kCollectorColor)
    dims = WorldDims(collectorRenderWidth, collectorRenderWidth)
    tl = topLeftPos(o.pos, dims)
    for y in [tl.y, tl.y - dims.h]
        for x in tl.x+1 : 5 : tl.x-1 + dims.w
            nudge = Vector2D(rand(0.0:0.01:2.0,2)...)
            renderRectCentered(cam, renderer, WorldPos(x,y)+nudge, WorldDims(2,10), unitColor)
        end
    end
    for x in [tl.x, tl.x + dims.w]
        for y in tl.y-1 : -5 : tl.y+1 - dims.h
            nudge = Vector2D(rand(0.0:0.01:2.0,2)...)
            renderRectCentered(cam, renderer, WorldPos(x,y)+nudge, WorldDims(10,2), unitColor)
        end
    end
    renderUnit(o, playerColor, cam, renderer, dims, kCollectorColor)
end
function render(o::Fighter, playerColor, cam::Camera, renderer)
    dims = WorldDims(unitRenderWidth, unitRenderWidth)
    renderUnit(o, playerColor, cam, renderer, dims, kFighterColor)
end

abstract type AbstractButton end
mutable struct MenuButton <: AbstractButton
    enabled::Bool
    pos::UIPixelPos
    dims::UIPixelDims
    text::String
    callBack
end
mutable struct KeyButton <: AbstractButton
    enabled::Bool
    pos::UIPixelPos
    dims::UIPixelDims
    text::String
    callBack
end

mutable struct CheckboxButton
    toggled::Bool
    button::MenuButton
end

import Base.run
run(b::AbstractButton) = b.callBack()
function run(b::CheckboxButton)
    b.toggled = !b.toggled
    b.button.callBack(b.toggled)
end

function render(b::AbstractButton, cam::Camera, renderer, color, fontSize)
    if (!b.enabled)
         return
    end
    topLeft = topLeftPos(b.pos, b.dims)
    screenPos = toScreenPos(topLeft, cam)
    rect = SDL2.Rect(screenPos..., toScreenPixelDims(b.dims, cam)...)
    x,y = Int[0], Int[0]
    SDL2.GetMouseState(pointer(x), pointer(y))
    if clickedButton == b
        if mouseOnButton(UIPixelPos(x[],y[]),b,cam)
            color = color - 50
        else
            color = color - 30
        end
    else
        if mouseOnButton(UIPixelPos(x[],y[]),b,cam)
            color = color - 10
        end
    end
    SetRenderDrawColor(renderer, color)
    SDL2.RenderFillRect(renderer, Ref(rect) )
    renderText(renderer, cam, b.text, b.pos; fontSize = fontSize)
end

function render(b::MenuButton, cam::Camera, renderer)
    render(b, cam, renderer, kMenuButtonColor, kMenuButtonFontSize)
end
function render(b::KeyButton, cam::Camera, renderer)
    render(b, cam, renderer, kKeySettingButtonColor, kKeyButtonFontSize)
end

function render(b::CheckboxButton, cam::Camera, renderer)
    # Hack: move button text offcenter before rendering to accomodate checkbox
    offsetText = " "
    text_backup = b.button.text
    b.button.text = offsetText * b.button.text
    render(b.button, cam, renderer)
    b.button.text = text_backup

    # Render checkbox
    render_checkbox_square(b.button, 6, SDL2.Color(200,200,200, 255), cam, renderer)

    if b.toggled
        # Inside checkbox "fill"
        render_checkbox_square(b.button, 8, SDL2.Color(100,100,100, 255), cam, renderer)
    end
end

function render_checkbox_square(b::AbstractButton, border, color, cam, renderer)
    checkbox_radius = b.dims.h/2.0 - border  # (checkbox is a square)
    topLeft = topLeftPos(b.pos, b.dims)
    topLeft = topLeft + border
    screenPos = toScreenPos(topLeft, cam)
    screenDims = toScreenPixelDims(UIPixelDims(checkbox_radius*2, checkbox_radius*2), cam)
    rect = SDL2.Rect(screenPos..., screenDims...)
    SetRenderDrawColor(renderer, color)
    SDL2.RenderFillRect(renderer, Ref(rect) )
end
