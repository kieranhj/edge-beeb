.LaserFrame0
;    defb 0,0,0,0,0,0,0,0,0,0,0,0
;    ld e,(ix+0)
;    inc ixl
;    ld d,(ix+0)
;    inc ixl
;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),8
;    res 3,h
;    ld (hl),0

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73
    inc hl
    set 3,h
    ld (hl),8
    res 3,h
    ld (hl),134

;    defb 0,0,0,0,0,0,0,0,0,0,0,0
;    ld l,(ix+0)
    inc ixl
;    ld h,(ix+0)
    inc ixl
;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
    ld (hl),194
    res 3,h
    ld (hl),128

;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
    ld (hl),194
    res 3,h
    ld (hl),128
;    defb 0,0,0,192,0,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),128

;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),8
;    res 3,h
;    ld (hl),0

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73
    inc hl
    set 3,h
    ld (hl),8
    res 3,h
    ld (hl),134

    jp (iy)

.LaserFrame5
;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73

;    defb 0,0,0,0,0,0,0,0,0,0,0,0
;    ld l,(ix+0)
    inc ixl
;    ld h,(ix+0)
    inc ixl
;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
    ld (hl),194
    res 3,h
    ld (hl),128

;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
    ld (hl),194
    res 3,h
    ld (hl),128
;    defb 0,0,0,192,0,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),128

;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73

    jp (iy)

.LaserFrame4
;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73

;    defb 0,0,0,0,0,0,0,0,0,0,0,0
;    ld l,(ix+0)
    inc ixl
;    ld h,(ix+0)
    inc ixl
;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
    ld (hl),194
    res 3,h
    ld (hl),128

;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
    ld (hl),194
    res 3,h
    ld (hl),128
;    defb 0,0,0,192,0,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),128

;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),73

    jp (iy)

.LaserFrame3
;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),64

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
    ld (hl),148

;    defb 0,0,0,0,0,0,0,0,0,0,0,0
;    ld l,(ix+0)
    inc ixl
;    ld h,(ix+0)
    inc ixl
;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
    ld (hl),194
    res 3,h
    ld (hl),128

;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
    ld (hl),194
    res 3,h
    ld (hl),128
;    defb 0,0,0,192,0,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),192
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),128

;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),64

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148
    inc hl
    set 3,h
    ld (hl),64
    res 3,h
    ld (hl),148

    jp (iy)

.LaserFrame2
;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148

;    defb 0,0,0,0,0,0,0,0,0,0,0,0
;    ld l,(ix+0)
    inc ixl
;    ld h,(ix+0)
    inc ixl
;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192

;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
    ld (hl),44
    res 3,h
    ld (hl),192

;    defb 0,0,0,192,0,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
;    ld (hl),0
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),192

;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64
    inc hl
    set 3,h
;    ld (hl),0
    res 3,h
    ld (hl),148

    jp (iy)

.LaserFrame1
;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64

;    defb 0,0,0,0,0,0,0,0,0,0,0,0
;    ld l,(ix+0)
    inc ixl
;    ld h,(ix+0)
    inc ixl
;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192

;    defb 192,0,44,192,194,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    ld (hl),192

;    defb 0,0,0,192,0,128,0,0,0,0,0,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;

;    defb 0,0,0,0,64,0,44,0,44,0,8,0
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;

;    defb 0,64,0,148,64,148,44,73,44,73,8,134
    ld l,(ix+0)
    inc ixl
    ld h,(ix+0)
    inc ixl
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
    res 3,h
    inc hl
    set 3,h
;
;    ld (hl),0
    res 3,h
    ld (hl),64

    jp (iy)
