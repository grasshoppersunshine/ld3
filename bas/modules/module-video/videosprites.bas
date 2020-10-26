#include once "inc/videosprites.bi"

const FORMAT256 = SDL_PIXELFORMAT_INDEX8
const FORMATRGB = SDL_PIXELFORMAT_ARGB8888

sub VideoSprites.init(v as Video ptr)
    
    this._reset
    this._renderer = v->getRenderer()
    
end sub

sub VideoSprites._reset()
    
    redim this._metrics(0) as VideoSpritesMetrics
    redim this._sprites(0) as SDL_Rect
    
    this._texture  = 0
    this._pixel_format = 0
    this._surface  = 0
    this._pixels   = 0
    this._renderer = 0
    this._palette  = 0
    this._sdl_palette = 0
    this._canvas_w = 0
    this._canvas_h = 0
    this._w = 0
    this._h = 0
    this._center_x = 0
    this._center_y = 0
    this._transparent_index = -1
    this._colormod = &hffffff
    this._alphamod = &hff
    this._count = 0
    
    dim n as integer
    for n = 0 to 255
        this._sdl_colors(n).r = 0
        this._sdl_colors(n).g = 0
        this._sdl_colors(n).b = 0
        this._sdl_colors(n).a = 0
    next n
    
end sub

sub VideoSprites.release()
    
    if this._texture      then SDL_DestroyTexture(this._texture)
    if this._surface      then SDL_FreeSurface(this._surface)
    if this._pixel_format then SDL_FreeFormat(this._pixel_format)
    if this._pixels       then deallocate(this._pixels)
    if this._sdl_palette  then SDL_FreePalette(this._sdl_palette)
    
    this._reset
    
end sub

sub VideoSprites.setCenter(x as integer, y as integer)
    
    this._center_x = x
    this._center_y = y
    
end sub

sub VideoSprites.resetCenter()
    
    this._center_x = int(this._w*0.5)-1
    this._center_y = int(this._h*0.5)-1
    
end sub

sub VideoSprites.setPalette(p as Palette256 ptr)
    
    dim n as integer
    
    this._palette = p
    
    this._sdl_palette = SDL_AllocPalette(256)
    
    for n = 0 to 255
        this._sdl_colors(n).r = this._palette->red(n)
        this._sdl_colors(n).g = this._palette->grn(n)
        this._sdl_colors(n).b = this._palette->blu(n)
        this._sdl_colors(n).a = this._palette->getAlpha(n)
    next n
    
    SDL_SetPaletteColors(this._sdl_palette, @this._sdl_colors(0), 0, 256)
    'if this._pixel_format then
    '    SDL_SetPixelFormatPalette(this._pixel_format, this._palette->getPalette())
    'end if
    
end sub

function VideoSprites._getRenderTarget() as SDL_Texture ptr
    
    return SDL_GetRenderTarget(this._renderer)
    
end function

function VideoSprites.setAsTarget(renderTarget as SDL_Texture ptr = 0) as SDL_Texture ptr
    
    dim prevTarget as SDL_Texture ptr
    prevTarget = this._getRenderTarget()
    
    if renderTarget = 0 then renderTarget = this._texture
    if SDL_SetRenderTarget( this._renderer, renderTarget ) <> 0 then
        print *SDL_GetError()
        end
    end if
    
    return prevTarget
    
end function

type DimensionsType
    _w as ushort
    _h as ushort
    declare property w() as integer
    declare property h() as integer
    declare property area() as integer
end type
property DimensionsType.w() as integer
    return (this._w shr 3)
end property
property DimensionsType.h() as integer
    return this._h
end property
property DimensionsType.area() as integer
    return this.w * this.h
end property

sub VideoSprites.loadBsv(filename as string, w as integer, h as integer, crop as integer = 0)
    
    type HeaderType
        a as ubyte
        b as ubyte
        c as ubyte
        d as ubyte
        e as ubyte
        f as ubyte
        g as ubyte
    end type
    
    dim target as SDL_Texture ptr
    dim header as HeaderType
    dim dimensions as DimensionsType
    dim filesize as integer
    dim count as integer
    dim as integer offx, offy
    dim as integer x, y
    dim as ubyte r, g, b, a
    dim as ubyte c
    
    if this._texture then
        SDL_DestroyTexture(this._texture)
        this._texture = 0
    end if
    
    w = iif(w > 0, w, this._w)
    h = iif(h > 0, h, this._h)
    
    offx = 0: offy = 0
    
    open filename for binary as #1
        get #1, , header
        count = 0
        while not eof(1)
            get #1, , dimensions
            for y = 0 to dimensions.h-1
                for x = 0 to dimensions.w-1
                    get #1, , c
                next x
            next y
            count += 1
        wend
    close #1
    
    this._canvas_w = 12 * w
    this._canvas_h = int(count/12+0.9999) * h
    this._w = iif(w > 0, w, this._canvas_w)
    this._h = iif(h > 0, h, this._canvas_h)
    
    this._texture = SDL_CreateTexture( this._renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_TARGET, this._canvas_w, this._canvas_h)
    this._pixel_format = SDL_AllocFormat( SDL_PIXELFORMAT_ARGB8888 )
    'if this._palette then
    '    SDL_SetPixelFormatPalette(this._pixel_format, this._palette->getPalette())
    'end if
    
    target = this._getRenderTarget()
    
    SDL_SetRenderDrawBlendMode( this._renderer, SDL_BLENDMODE_NONE )
    SDL_SetRenderTarget( this._renderer, this._texture )
    
    open filename for binary as #1
        get #1, , header
        while not eof(1)
            get #1, , dimensions
            if (offx + dimensions.w) > this._canvas_w then
                offx = 0
                offy += this._h
            end if
            for y = 0 to dimensions.h-1
                for x = 0 to dimensions.w-1
                    get #1, , c
                    r = this._palette->red(c)
                    g = this._palette->grn(c)
                    b = this._palette->blu(c)
                    a = iif(c = this._transparent_index, 0, this._palette->getAlpha(c))
                    SDL_SetRenderDrawColor( this._renderer, r, g, b, a )
                    SDL_RenderDrawPoint( this._renderer, offx+x, offy+y )
                next x
            next y
            offx += dimensions.w
        wend
    close #1
    
    SDL_SetTextureBlendMode( this._texture, SDL_BLENDMODE_BLEND )
    
    this.dice
    this._buildMetrics crop
    this.setAsTarget( target )
    
end sub

sub VideoSprites.loadBmp(filename as string, w as integer = 0, h as integer = 0, crop as integer = 0)
    
    dim imageSurface as SDL_Surface ptr
    dim fmt as uinteger
    
    if this._texture then
        SDL_DestroyTexture(this._texture)
        this._texture = 0
    end if
    
    imageSurface = SDL_LoadBMP(filename)
    if imageSurface <> NULL then
        this._canvas_w = imageSurface->w
        this._canvas_h = imageSurface->h
        SDL_SetColorKey( imageSurface, SDL_TRUE, SDL_MapRGBA(imageSurface->format, 255, 0, 255, 255) )
        this._texture = SDL_CreateTextureFromSurface( this._renderer, imageSurface )
        SDL_FreeSurface(imageSurface)
    end if
    
    SDL_QueryTexture( this._texture, @fmt, 0, 0, 0 )
    this._pixel_format = SDL_AllocFormat( fmt )
    
    w = iif(w > 0, w, this._w)
    h = iif(h > 0, h, this._h)
    this._w = iif(w > 0, w, this._canvas_w)
    this._h = iif(h > 0, h, this._canvas_h)
    
    this.dice
    this._buildMetrics crop
    
end sub

sub VideoSprites.saveBmp(filename as string, xscale as double = 1.0, yscale as double = 1.0)
    
    dim surface as SDL_Surface ptr
    dim texture as SDL_Texture ptr
    dim target as SDL_Texture ptr
    dim w as integer
    dim h as integer
    
    target = this._getRenderTarget()
    
    w = int(this._canvas_w * xscale)
    h = int(this._canvas_h * yscale)
    if (w = this._canvas_w) and (h = this._canvas_h) then
        this._textureToSurface this._texture, surface
        SDL_SaveBMP(surface, filename)
        SDL_FreeSurface(surface)
    else
        texture = SDL_CreateTexture( this._renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_TARGET, w, h)
        SDL_SetTextureBlendMode( texture, SDL_BLENDMODE_BLEND )
        SDL_SetRenderTarget( this._renderer, texture )
        SDL_RenderCopy( this._renderer, this._texture, 0, 0)
        this._textureToSurface texture, surface
        SDL_SaveBMP(surface, filename)
        SDL_FreeSurface(surface)
        SDL_DestroyTexture(texture)
    end if
    
    this.setAsTarget( target )
    
end sub

sub VideoSprites.saveBmp8bit(filename as string, xscale as double = 1.0, yscale as double = 1.0)
    
    dim surface as SDL_Surface ptr
    dim surface8bit as SDL_Surface ptr
    dim s8 as SDL_Surface ptr
    dim fmt as SDL_PixelFormat
    dim texture as SDL_Texture ptr
    dim target as SDL_Texture ptr
    dim w as integer
    dim h as integer
    
    fmt.format = SDL_PIXELFORMAT_INDEX8
    fmt.palette = this._sdl_palette
    fmt.BitsPerPixel = 8
    fmt.BytesPerPixel = 1
    
    target = this._getRenderTarget()
    
    w = int(this._canvas_w * xscale)
    h = int(this._canvas_h * yscale)
    if (w = this._canvas_w) and (h = this._canvas_h) then
        this._textureToSurface this._texture, surface
        SDL_SetSurfacePalette(s8, this._sdl_palette)
        surface8bit = SDL_ConvertSurface(surface, @fmt, 0)
        SDL_SetSurfacePalette(surface8bit, this._sdl_palette)
        SDL_SaveBMP(surface8bit, filename)
        SDL_FreeSurface(surface)
        SDL_FreeSurface(surface8bit)
    else
        texture = SDL_CreateTexture( this._renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_TARGET, w, h)
        SDL_SetTextureBlendMode( texture, SDL_BLENDMODE_BLEND )
        SDL_SetRenderTarget( this._renderer, texture )
        SDL_RenderCopy( this._renderer, this._texture, 0, 0)
        this._textureToSurface texture, surface
        SDL_SetSurfacePalette(s8, this._sdl_palette)
        surface8bit = SDL_ConvertSurface(surface, @fmt, 0)
        SDL_SaveBMP(surface8bit, filename)
        SDL_FreeSurface(surface)
        SDL_FreeSurface(surface8bit)
        SDL_DestroyTexture(texture)
    end if
    
    this.setAsTarget( target )
    
end sub

sub VideoSprites.dice(w as integer = 0, h as integer = 0)
    
    dim across as integer
    dim count as integer
    dim down as integer
    dim x as integer
    dim y as integer
    dim n as integer
    
    w = iif(w > 0, w, this._w)
    h = iif(h > 0, h, this._h)
    
    across = int((this._canvas_w / w) + 0.9999)
    down   = int((this._canvas_h / h) + 0.9999)
    
    count = across*down
    
    redim this._sprites(count) as SDL_Rect
    this._count = count
    
    n = 0
    for y = 0 to down-1
        for x = 0 to across-1
            this._sprites(n).x = x * w
            this._sprites(n).y = y * h
            this._sprites(n).w = w
            this._sprites(n).h = h
            n += 1
        next x
    next y
    
    this._w = w
    this._h = h
    
end sub

sub VideoSprites._erase(sprite_id as integer, quad as integer = 0)
    
    dim blendMode as SDL_BlendMode
    dim as ubyte r, g, b, a
    
    SDL_GetRenderDrawBlendMode( this._renderer, @blendMode )
    SDL_GetRenderDrawColor( this._renderer, @r, @g, @b, @a )
    
    SDL_SetRenderDrawBlendMode( this._renderer, SDL_BLENDMODE_NONE )
    SDL_SetRenderDrawColor( this._renderer, rgb_r(quad), rgb_g(quad), rgb_b(quad), rgb_a(quad) )
    SDL_RenderFillRect( this._renderer, @this._sprites(sprite_id) )
    
    SDL_SetRenderDrawBlendMode( this._renderer, blendMode )
    SDL_SetRenderDrawColor( this._renderer, r, g, b, a )
    
end sub

sub VideoSprites._buildMetrics(crop as integer = 0)
    
    dim as SDL_Texture ptr texture, target
    dim as SDL_Rect ptr sprite
    dim as uinteger fmt, c
    dim as integer top, lft, rgt, btm
    dim as integer w, h, bpp, accss
    dim as integer x, y, n
    dim as ubyte r, g, b, a
    
    target = this._getRenderTarget()
    
    this._center_x = int(this._w*0.5)-1
    this._center_y = int(this._h*0.5)-1
    
    redim this._metrics(this._count) as VideoSpritesMetrics
    
    SDL_QueryTexture( this._texture, @fmt, @accss, @w, @h )
    if accss <> SDL_TEXTUREACCESS_TARGET then
        texture = SDL_CreateTexture( this._renderer, fmt, SDL_TEXTUREACCESS_TARGET, w, h )
        SDL_SetTextureBlendMode( texture, SDL_BLENDMODE_BLEND )
        SDL_SetRenderTarget( this._renderer, texture )
        SDL_RenderCopy( this._renderer, this._texture, NULL, NULL )
        SDL_DestroyTexture(this._texture)
        this._texture = texture
    end if
    
    this._textureToSurface this._texture, this._surface
    if this._surface = 0 then exit sub
    
    this.setAsTarget
    for n = 0 to this._count-1
        sprite = @this._sprites(n)
        top = -1: btm = -1
        lft = -1: rgt = -1
        for y = 0 to this._h-1
            for x = 0 to this._w-1
                c = this._getPixel(sprite->x+x, sprite->y+y)
                SDL_GetRGBA(c, this._surface->format, @r, @g, @b, @a)
                if a > 0 then
                    if (lft = -1) or (x < lft) then lft = x
                    if (rgt = -1) or (x > rgt) then rgt = x
                    if top = -1 then top = y
                    btm = y
                end if
            next x
        next y
        top = iif(top > -1, top, 0)
        btm = iif(btm > -1, btm, this._h-1)
        lft = iif(lft > -1, lft, 0)
        rgt = iif(rgt > -1, rgt, this._w-1)
        if crop then
            this._erase n
            for y = top to btm
                for x = lft to rgt
                    c = this._getPixel(sprite->x+x, sprite->y+y)
                    SDL_GetRGBA(c, this._surface->format, @r, @g, @b, @a)
                    SDL_SetRenderDrawColor( this._renderer, r, g, b, a )
                    SDL_RenderDrawPoint( this._renderer, sprite->x+x-lft, sprite->y+y-top )
                next x
            next y
            btm -= top: rgt -= lft
            top = 0: lft = 0
        end if
        this._metrics(n).top = top
        this._metrics(n).btm = btm
        this._metrics(n).lft = lft
        this._metrics(n).rgt = rgt
    next n
    
    SDL_FreeSurface( this._surface ): this._surface = 0
    
    this.setAsTarget(target)
    
end sub

sub VideoSprites.convertPalette(p as Palette256 ptr)
    
    dim as integer ptr pixels
    dim as uinteger bytes
    dim as integer pitch
    dim as integer colorIndex, match, colr, n
    dim as ubyte r, g, b, a
    
    this._textureToPixels(this._texture, pixels, bytes, pitch)
    for n = 0 to (bytes shr 2)-1
        colr = pixels[n]
        SDL_GetRGBA(colr, this._pixel_format, @r, @g, @b, @a)
        colorIndex = this._palette->match(r, g, b)
        if colorIndex > -1 then
            pixels[n] = p->getColor(colorIndex, this._pixel_format)
        end if
    next n
    
    SDL_UpdateTexture(this._texture, 0, pixels, pitch)
    
    deallocate(pixels)
    
    this._palette = p
    
end sub

sub VideoSprites._textureToPixels(byval texture as SDL_Texture ptr, byref pixels as any ptr, byref size_in_bytes as uinteger, byref pitch as integer)
    
    dim as SDL_Texture ptr target
    dim as uinteger fmt
    dim as integer bpp, w, h
    
    SDL_QueryTexture( this._texture, @fmt, 0, @w, @h )
    bpp = SDL_BYTESPERPIXEL(fmt)
    pitch = w * bpp
    
    size_in_bytes = w*h*bpp
    pixels = allocate(size_in_bytes): if pixels = 0 then exit sub
    
    target = this.setAsTarget( texture )
    if SDL_RenderReadPixels( this._renderer, 0, fmt, pixels, pitch) <> 0 then
        print *SDL_GetError()
        end
    end if
    this.setAsTarget( target )
    
end sub

sub VideoSprites._textureToSurface(byval texture as SDL_Texture ptr, byref surface as SDL_Surface ptr)
    
    dim as SDL_Texture ptr target
    dim as integer w, h, bpp, accss
	dim as uinteger fmt, rmask, gmask, bmask, amask
	
    SDL_QueryTexture( iif(texture <> 0, texture, this._texture), @fmt, @accss, @w, @h )
	SDL_PixelFormatEnumToMasks( fmt, @bpp, @rmask, @gmask, @bmask, @amask )
	
    if accss <> SDL_TEXTUREACCESS_TARGET then
        exit sub
    end if
    
    surface = SDL_CreateRGBSurface(0, w, h, bpp, rmask, gmask, bmask, amask)
    
    target = this.setAsTarget( texture )
    
    SDL_LockSurface( surface )
    if SDL_RenderReadPixels( this._renderer, NULL, surface->format->format, surface->pixels, surface->pitch) <> 0 then
        print *SDL_GetError()
        end
    end if
	SDL_UnlockSurface( surface )
    
    this.setAsTarget( target )
    
end sub

function VideoSprites._getPixel(x as integer, y as integer) as uinteger
    
    dim as integer pitch
    
    if this._surface <> 0 then
        if this._surface->pixels <> 0 then
            pitch = (this._surface->pitch shr 2)
            return cast(uinteger ptr, this._surface->pixels)[x+y*pitch]
        end if
    end if
    
    return 0
    
end function

sub VideoSprites.setTransparentColor(index as integer)
    
    this._transparent_index = index
    
end sub

sub VideoSprites.modSize(sprite_id as integer, w as integer, h as integer)
    
    this._sprites( sprite_id ).w = w
    this._sprites( sprite_id ).h = h
    
end sub

sub VideoSprites.putToScreen(sprite_id as integer, x as integer, y as integer)
    
    dim dst as SDL_RECT

	dst.x = x: dst.y = y
	dst.w = this._sprites( sprite_id ).w: dst.h = this._sprites( sprite_id ).h

    SDL_RenderCopy( this._renderer, this._texture, @this._sprites(sprite_id), @dst)
    
end sub

sub VideoSprites.putToScreenEx(sprite_id as integer, x as integer, y as integer, flip_horizontal as integer = 0, rotation_angle as double = 0, crop as SDL_RECT ptr = 0, dest as SDL_RECT ptr = 0)
    
    dim src as SDL_RECT
    dim dst as SDL_RECT
    
    src = this._sprites(sprite_id)
    
    if crop = 0 then
        if dest = 0 then
            dst.x = x: dst.y = y
            dst.w = this._sprites( sprite_id ).w: dst.h = this._sprites( sprite_id ).h
        end if
    else
        src.x += crop->x: src.y += crop->y
        src.w  = crop->w: src.h  = crop->h
        if dest = 0 then
            dst.x = x: dst.y = y
            dst.w = crop->w: dst.h = crop->h
        end if
    end if

    if dest <> 0 then
        dst = *dest
    end if
    
    dim center as SDL_POINT
    if rotation_angle = 0 then
        center.x = 0: center.y = 0
    else
        center.x = this._center_x: center.y = this._center_y
    end if
    
    SDL_RenderCopyEx( this._renderer, this._texture, @src, @dst, rotation_angle, @center, iif(flip_horizontal, SDL_FLIP_HORIZONTAL, 0))
    
end sub

sub VideoSprites.setColorMod(colr as integer)
    
    SDL_SetTextureColorMod(this._texture, rgb_r(colr), rgb_g(colr), rgb_b(colr))
    this._colormod = colr
    
end sub

function VideoSprites.getColorMod() as integer
    
    return this._colormod
    
end function

sub VideoSprites.setAlphaMod(a as integer)
    
    SDL_SetTextureAlphaMod(this._texture, a)
    this._alphamod = a
    
end sub

function VideoSprites.getAlphaMod() as integer
    
    return this._alphamod
    
end function

function VideoSprites.getCount() as integer
    
    return this._count
    
end function

sub VideoSprites.getMetrics(byval sprite_id as integer, byref x as integer, byref y as integer, byref w as integer, byref h as integer)
    
    if (sprite_id >= 0) and (sprite_id < this._count) then
        x = this._metrics(sprite_id).lft
        y = this._metrics(sprite_id).top
        w = this._metrics(sprite_id).rgt - x + 1
        h = this._metrics(sprite_id).btm - y + 1
    end if
    
end sub

sub VideoSprites.setBlendMode(blendmode_id as integer)
    
    select case blendmode_id
    case VideoBlendModes.None
        SDL_SetTextureBlendMode( this._texture, SDL_BLENDMODE_NONE )
    case VideoBlendModes.Blend
        SDL_SetTextureBlendMode( this._texture, SDL_BLENDMODE_BLEND )
    case VideoBlendModes.Add
        SDL_SetTextureBlendMode( this._texture, SDL_BLENDMODE_ADD )
    case VideoBlendModes.Modulate
        SDL_SetTextureBlendMode( this._texture, SDL_BLENDMODE_MOD )
    end select
    
end sub

