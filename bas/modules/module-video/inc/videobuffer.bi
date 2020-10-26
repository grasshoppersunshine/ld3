#pragma once
#inclib "videobuffer"
#include once "palette256.bi"
#include once "video.bi"

declare function SDL_CreateSurfaceFromTexture( renderer as SDL_RENDERER ptr, texture as SDL_Texture ptr ) as SDL_Surface ptr

type VideoBuffer
private:
    _video as Video ptr
    _texture as SDL_Texture ptr
    _renderer as SDL_Renderer ptr
    _palette as palette256 ptr
    _w as integer
    _h as integer
    
    declare sub _reset()
    declare function _getRenderTarget() as SDL_Texture ptr
    
public:
    declare sub init(v as Video ptr)
    declare sub release()
    declare sub setPalette(p as Palette256 ptr)
    declare sub loadBmp(filename as string)
    declare sub saveBmp(filename as string, xscale as double = 1.0, yscale as double = 1.0)
    declare sub putToScreen(src as SDL_RECT ptr = NULL, dst as SDL_RECT ptr = NULL)
    declare sub captureBackbuffer()
    declare sub putPixel(x as integer, y as integer, colr as integer)
    declare sub fillScreen(colr as integer, a255 as integer = &hff)
    declare sub fill(x as integer, y as integer, w as integer, h as integer, colr as integer, a255 as integer = &hff)
    declare sub outline(x as integer, y as integer, w as integer, h as integer, colr as integer, a255 as integer = &hff)
    declare function setAsTarget(renderTarget as SDL_Texture ptr = 0) as SDL_Texture ptr
end type
