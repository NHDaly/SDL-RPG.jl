struct Animation
    frames::Vector
    delays::Vector{Float32}
    donecallback
end
struct Sprite
    img::Ptr{SDL2.Texture}
    pos::ScreenPixelPos
    dims::ScreenPixelDims
end

function render(s::Sprite, pos::AbstractPos{C}, cam::Camera, renderer;
                size = nothing) where C
    src_rect=SDL2.Rect(s.pos..., s.dims...)
    render(s.img, pos, cam, renderer;
           size=size,
           src_rect=pointer_from_objref(src_rect),)
end

function load_bmp(renderer, file)
    surface = SDL2.LoadBMP(file)
    texture = SDL2.CreateTextureFromSurface(renderer, surface) # Will be C_NULL on failure.
    SDL2.FreeSurface(surface)
    texture
end

function render(a::Animation, pos::AbstractPos{C}, cam::Camera, renderer;
                size) where C
    render(first(a.frames), pos, cam, renderer; size=size)
end
function update!(a::Animation, dt)
    a.delays[1] -= dt
    # (while-loop instead of if-statement to account for dt larger than one frame)
    while a.delays[1] < 0  # tick to next frame
        if length(a.delays) >= 2
            a.delays[2] += a.delays[1]  # handle overflow larger than delays[1]
        end
        popfirst!(a.delays)
        if isempty(a.delays)
            a.donecallback()
            return
        end
        # Don't pop the last frame if delays is empty
        popfirst!(a.frames)
    end
end
