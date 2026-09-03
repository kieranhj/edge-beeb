;******************************************************************
; AI-GENERATED CODE
;------------------------------------------------------------------
; 6502 BBC Micro Incremental VGM (VGI) Music Player - zero page header
; Generated with the assistance of an AI model: Claude Opus 4.8
; (claude-opus-4-8). Companion to lib/vgiplayer.asm.
;
; INCLUDE this where you declare your zero page vars (see vgi_demo.asm),
; exactly like lib/vgcplayer.h.asm is used for the VGC player.
;
; The VGI player needs only 4 zero page bytes (two indirect pointers).
; All other state (the 11 per-stream decode contexts, the frame counter
; and a scratch byte) lives in absolute memory inside lib/vgiplayer.asm.
;
; It also needs a page-aligned 2.75 KB (11 x 256) decode workspace, the HI
; byte of which is passed to vgm_init in A. (The VGC player uses 2 KB / 8
; streams; VGI has 11 register streams, hence 11 pages.)
;******************************************************************

;-------------------------------
; workspace/zeropage vars
;-------------------------------

; The VGI player uses 4 zero page bytes (two 16-bit indirect pointers).
.VGI_ZP SKIP 4

vgi_src  = VGI_ZP + 0   ; current stream read ptr LO/HI (indirect byte fetch)
vgi_ring = VGI_ZP + 2   ; ring window ptr LO/HI (LO always 0, page-aligned)
