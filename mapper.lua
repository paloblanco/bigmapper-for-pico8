function _init()
	-- poke(0x5F36, 0x8) -- draw sprite 0 
    -- poke(0x5f36,1) -- multidisplay
    poke(0x5f36,9)
	poke(24365,1) -- mouse
    
    camera_all(0,0)
    
    -- mapping vars
    current_tile = 0
    undo_stack = {}
    viewgrid = true

    -- control vars
    -- mouse
    m0 = false
    m0p = false
    m1 = false
    m1p = false
    m2 = false
    m2p = false
    ms = 0 --scroll
    key=nil
    bucket=false
    movespeed=6
end

function _update()
    controls()
    if (m0 and (not bucket)) place_tile()
    if (m0 and (bucket)) fill_tile()
    if (m1) dropper_tile()
    

    -- keyboard
    if (check_key("5")) save_local()
    if (check_key("4")) save_export()

    if (check_key("g")) viewgrid = not viewgrid
    if (check_key("b")) bucket = not bucket
    if (check_key("z")) undo()

end

function fill_tile()
    local xx = mx\8
    local yy = my\8
    local tt = mget(xx,yy)
    local tnew = current_tile
    if (tt != tnew) flood(xx,yy,tnew,tt)
end

function flood(xx,yy,tnew,tt)
    local t_here = mget(xx,yy)
    if (t_here != tt) return
    if (xx<0) return
    if (xx>127) return
    if (yy<0) return
    if (yy>63) return
    add_undo(xx,yy)
    mset(xx,yy,tnew)
    -- _draw()
    -- flip()
    flood(xx-1,yy,tnew,tt)
    flood(xx+1,yy,tnew,tt)
    flood(xx,yy-1,tnew,tt)
    flood(xx,yy+1,tnew,tt)
end

function add_undo(xx,yy,kind)
    local u = {}
    u.xx=xx
    u.yy=yy
    u.tt=mget(xx,yy)
    u.t =flr(t())
    u.kind = kind or "tile"
    add(undo_stack,u)    
    if (#undo_stack > 10000) del(undo_stack,undo_stack[1])
end

function pop(t)
    local pop_item = t[#t]
    del(t,pop_item)
    return pop_item
end

function undo()
    if (#undo_stack<1) return
    local u = pop(undo_stack)
    if u.kind=="tile" then
        mset(u.xx,u.yy,u.tt)
    elseif u.kind=="flood" then -- this is broken right now
        local tt = mget(u.xx,u.yy)
        flood(u.xx,u.yy,u.t,tt)
    end
    if (#undo_stack<1) return
    local tnext = undo_stack[#undo_stack].t
    if (u.t==tnext) undo()
end

function dropper_tile()
    local xx = mx\8
    local yy = my\8
    if xx>=0 and xx < 128 and yy>=0 and yy < 64 then
        current_tile = mget(xx,yy)
    end
end

function place_tile()
    local xx = mx\8
    local yy = my\8
    local t_here=mget(xx,yy)
    if (t_here==current_tile) return
    if xx>=0 and xx < 128 and yy>=0 and yy < 64 then
        add_undo(xx,yy)
        mset(xx,yy,current_tile)
    end
end

function _draw()
	for i=0,3,1 do
        _map_display(i)
        camera(128*(i%2) + camx,128*(i\2)+camy)
        draw_all()
    end
    draw_picker()
    draw_status()
end

function draw_all()
    cls(1)
    palt(0)
    map()
    grid()
    circfill(mx,my,2,7)
    palt()
end

function grid()
    if (not viewgrid) return
    gridoffx=0
    gridoffy=0
    gridx=16
    gridy=14
    gcolor=6
    for xx=gridoffx,127,gridx do
        line(xx*8,0,xx*8,64*8,gcolor)
    end
    for yy=gridoffy,63,gridy do
        line(0,yy*8,128*8,yy*8,gcolor)
    end
end

function camera_all(x,y)
    camx = x
    camy = y
end

function controls()
    move_speed = movespeed
    -- ESDF for camera
    if (btn(0,1)) camx += -move_speed
    if (btn(1,1)) camx += move_speed
    if (btn(2,1)) camy += -move_speed
    if (btn(3,1)) camy += move_speed

    -- mouse
    update_mouse()

    -- arrows for tile selection
    if (btnp(0,0)) current_tile += -1
    if (btnp(1,0)) current_tile += 1
    if (btnp(2,0)) current_tile += -16
    if (btnp(3,0)) current_tile += 16
    if (current_tile<0) current_tile = current_tile+8*16 
    if (current_tile>127) current_tile = current_tile-8*16

    key = get_key()

end

function save_local()
    cstore(0,0,0X3100)
end

function save_export()
    cstore(0,0,0X3100,"luigi_bigroom.p8")
end

function save_import()
end

function draw_picker()
    _map_display(2)
    camera()
    line(0,63,128,63,6)
    palt(0)
    spr(0,0,64,16,8)
    
    ctilex = 8*(current_tile%16)
    ctiley = 64 + 8*(current_tile\16)
    rect(ctilex,ctiley,ctilex+7,ctiley+7,7)
    palt()
    if (myraw > 128+64) circfill(mxraw,myraw-128,2)
end

function draw_status()
    _map_display(3)
    camera()
    line(0,100,128,100,7)
    if bucket then
        print("fill",1,102,7)
    else
        print("point",1,102,7)
    end
end

-- control stuff
function get_key()
    return(stat(31))
end

function check_key(k)
    return key==k
end

function get_m0()
    return stat(34)&1
end

function update_mouse()
    local m0new = stat(34)&1
    local m1new = (stat(34)&2) >>> 1
    local m2new = (stat(34)&4) >>> 2

    m0new = m0new==1
    m1new = m1new==1
    m2new = m2new==1

    m0p = false
    m1p = false
    m2p = false

    if (m0new and not m0) m0p = true
    if (m1new and not m1) m1p = true
    if (m2new and not m2) m2p = true

    m0 = m0new
    m1 = m1new
    m2 = m2new

    ms = stat(36)

    mxraw = stat(32)
    myraw = stat(33)
    mx = stat(32) + camx
	my = stat(33) + camy
end
