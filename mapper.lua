-- TODO:
-- save, load, and select slots - working
-- detect number of saves, auto save to end - working
-- way to define size of map to save px9 workload
-- autotiling method
-- memswapping - send to working cart, save locally, export, etc
-- decide on address or lengths saved at end of memory - throw warning if length too high
-- drawing utils - quick block fill


function _init()
	-- poke(0x5F36, 0x8) -- draw sprite 0 
    -- poke(0x5f36,1) -- multidisplay
    poke(0x5f36,9)
	poke(24365,1) -- mouse
    poke(0x5f56,0x80) -- extended mem for map
    poke(0x5f57,0) -- map width. 256. yuge.
    
    camera_all(0,0)

	--clear extended
	-- memset(0x8000,0,0x7fff)
    -- poke(0xffff,0)
	--clear regular
	--memset(0x2000,0,0x1000)
	-- memset(0x3000,0,0x0100)

	--maptest
	xbound=16--256
	ybound=16--127
	-- for xx=0,xbound-1,1 do mset(xx,0,1) mset(xx,ybound-1,1) end
	-- for yy=0,ybound-1,1 do mset(0,yy,1) mset(xbound-1,yy,1) end
    
    -- mapping vars
    current_tile = 0
    undo_stack = {}
    viewgrid = true

	current_address = 0x2000
    len_address = 0x2fff
	address_list = {}
	current_level_ix = 0

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
	if (check_key("1")) compress_map_to_location()
	if (check_key("2")) decompress_from_memory_to_map()
	if (check_key("3")) cycle_current_level_ix()

    if (check_key("4")) save_export()
    if (check_key("5")) save_local()

	if (check_key("6")) delete_current_ix()
    if (check_key("7")) clear_working_map()
    if (check_key("8")) clear_longterm_memory()

    if (check_key("g")) viewgrid = not viewgrid
    if (check_key("b")) bucket = not bucket
    if (check_key("z")) undo()

end

function clear_working_map()
    memset(0x8000,0,0x7fff)
    poke(0xffff,0)
end

function clear_longterm_memory()
    memset(0x2000,0,0x1000)
end

function delete_current_ix()
	dst = 0x6000
	mem_add=0
	new_list = {}
	for i=1,#address_list,1 do
		src, len = address_list[i][1],address_list[i][2]
		if i < current_level_ix then
			memcpy(dst,src,len)
			mem_add += len
			dst += len
			add(new_list,{src,len})
		elseif i > current_level_ix then
			memcpy(dst,src,len)
			src = 0x2000 + (dst-0x6000)
			mem_add += len
			dst += len
			add(new_list,{src,len})
		end
	end
	--clean map
	memset(0x2000,0,0x0fff)
	-- copy back
	memcpy(0x2000,0x6000,dst-0x6000)
	address_list = new_list
	popup("deleted "..current_level_ix)
end

function compress_map_to_location()
	-- regular map is at 0x2000
	length = px9_comp(0,0,xbound,ybound,current_address,mget)
	add(address_list,{current_address,length})
	popup("Level len "..length)
	current_address += length
end

function popup(str)
	for i=1,30,1 do
		rectfill(30,30,90,90,7)
		print(str,34,45,0)
		flip()
	end
end


function decompress_from_memory_to_map()
	if #address_list==0 then 
		source = 0x2000
	else
		source = address_list[current_level_ix][1]
	end
	source=0x2000
	-- first clear the map
	memset(0x8000,0,0x7fff)
	-- decomp from regular map memory
	px9_decomp(0,0,source,mget,mset)
end

function cycle_current_level_ix()
	if #address_list == 0 then
		current_level_ix = 0
		return
	end
	current_level_ix = (current_level_ix % #address_list) + 1
end

function fill_tile()
    local xx = mousex\8
    local yy = mousey\8
    local tt = mget(xx,yy)
    local tnew = current_tile
    if (tt != tnew) flood(xx,yy,tnew,tt)
end

function flood(xx,yy,tnew,tt)
    local t_here = mget(xx,yy)
    if (t_here != tt) return
    if (xx<0) return
    if (xx>255) return
    if (yy<0) return
    if (yy>127) return
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
    local xx = mousex\8
    local yy = mousey\8
    if xx>=0 and xx < 256 and yy>=0 and yy < 128 then
        current_tile = mget(xx,yy)
    end
end

function place_tile()
    local xx = mousex\8
    local yy = mousey\8
    local t_here=mget(xx,yy)
    if (t_here==current_tile) return
    if xx>=0 and xx < 256 and yy>=0 and yy < 128 then
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
    circfill(mousex,mousey,2,7)
    palt()
end

function grid()
    if (not viewgrid) return
    gridoffx=0
    gridoffy=0
    gridx=16
    gridy=16
    gcolor=6
    for xx=gridoffx,255,gridx do
        line(xx*8,0,xx*8,128*8,gcolor)
    end
    for yy=gridoffy,127,gridy do
        line(0,yy*8,256*8,yy*8,gcolor)
    end
end

function camera_all(x,y)
    camx = x
    camy = y
end

function controls()
    move_speed = movespeed*2
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
	print(mousex\8,30,102,7)
	print(mousey\8,48,102,7)
	print("address: "..current_address,1,110,7)
	print("ix: "..current_level_ix,1,118,7)
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
    mousex = stat(32) + camx
	mousey = stat(33) + camy
end


------------------------
-- COMPRESSION
------------------------

-- CREDIT TO ZEP & CO

-- px9 decompress
-- by zep

-- x0,y0 where to draw to
-- src   compressed data address
-- vget  read function (x,y)
-- vset  write function (x,y,v)

function
    px9_decomp(x0,y0,src,vget,vset)

    local function vlist_val(l, val)
        -- find position
        for i=1,#l do
            if l[i]==val then
                for j=i,2,-1 do
                    l[j]=l[j-1]
                end
                l[1] = val
                return i
            end
        end
    end

    -- bit cache is between 16 and 
    -- 31 bits long with the next
    -- bit always aligned to the
    -- lsb of the fractional part
    local cache,cache_bits=0,0
    function getval(bits)
        if cache_bits<16 then
            -- cache next 16 bits
            cache+=%src>>>16-cache_bits
            cache_bits+=16
            src+=2
        end
        -- clip out the bits we want
        -- and shift to integer bits
        local val=cache<<32-bits>>>16-bits
        -- now shift those bits out
        -- of the cache
        cache=cache>>>bits
        cache_bits-=bits
        return val
    end

    -- get number plus n
    function gnp(n)
        local bits=0
        repeat
            bits+=1
            local vv=getval(bits)
            n+=vv
        until vv<(1<<bits)-1
        return n
    end

    -- header

    local 
        w,h_1,      -- w,h-1
        eb,el,pr,
        x,y,
        splen,
        predict
        =
        gnp"1",gnp"0",
        gnp"1",{},{},
        0,0,
        0
        --,nil

    for i=1,gnp"1" do
        add(el,getval(eb))
    end
    for y=y0,y0+h_1 do
        for x=x0,x0+w-1 do
            splen-=1

            if(splen<1) then
                splen,predict=gnp"1",not predict
            end

            local a=y>y0 and vget(x,y-1) or 0

            -- create vlist if needed
            local l=pr[a]
            if not l then
                l={}
                for e in all(el) do
                    add(l,e)
                end
                pr[a]=l
            end

            -- grab index from stream
            -- iff predicted, always 1

            local v=l[predict and 1 or gnp"2"]

            -- update predictions
            vlist_val(l, v)
            vlist_val(el, v)

            -- set
            vset(x,y,v)

            -- advance
            x+=1
            y+=x\w
            x%=w
        end
    end
end

-- px9 compress
-- by zep

-- x0,y0 where to read from
-- w,h   image width,height
-- dest  address to store
-- vget  read function (x,y)

function 
	px9_comp(x0,y0,w,h,dest,vget)
	
		local dest0=dest
		local bit=1 
		local byte=0
	
		local function vlist_val(l, val)
			-- find positon
			for i=1,#l do
				if l[i] == val then
					-- jump to top
					for j=i,2,-1 do
						l[j]=l[j-1]
					end
					l[1] = val
					return i
				end
			end
		end
	
		function putbit(bval)
			if (bval) byte+=bit 
			poke(dest, byte) bit<<=1
			if (bit==256) then
				bit=1 byte=0
				dest += 1
			end
		end
	
		function putval(val, bits)
			for i=0,bits-1 do
				putbit(val&1<<i > 0)
			end
		end
	
		function putnum(val)
			local bits = 0
			repeat
				bits += 1
				local mx=(1<<bits)-1
				local vv=min(val,mx)
				putval(vv,bits)
				val -= vv
			until vv<mx
		end
	
	
		-- first_used
	
		local el={}
		local found={}
		local highest=0
		for y=y0,y0+h-1 do
			for x=x0,x0+w-1 do
				c=vget(x,y)
				if not found[c] then
					found[c]=true
					add(el,c)
					highest=max(highest,c)
				end
			end
		end
	
		-- header
	
		local bits=1
		while highest >= 1<<bits do
			bits+=1
		end
	
		putnum(w-1)
		putnum(h-1)
		putnum(bits-1)
		putnum(#el-1)
		for i=1,#el do
			putval(el[i],bits)
		end
	
	
		-- data
	
		local pr={} -- predictions
	
		local dat={}
	
		for y=y0,y0+h-1 do
			for x=x0,x0+w-1 do
				local v=vget(x,y)  
	
				local a=0
				if (y>y0) a+=vget(x,y-1)
	
				-- create vlist if needed
				local l=pr[a]
				if not l then
					l={}
					for i=1,#el do
						l[i]=el[i]
					end
					pr[a]=l
				end
	
				-- add to vlist
				add(dat,vlist_val(l,v))
			   
				-- and to running list
				vlist_val(el, v)
			end
		end
	
		-- write
		-- store bit-0 as runtime len
		-- start of each run
	
		local nopredict
		local pos=1
	
		while pos <= #dat do
			-- count length
			local pos0=pos
	
			if nopredict then
				while dat[pos]!=1 and pos<=#dat do
					pos+=1
				end
			else
				while dat[pos]==1 and pos<=#dat do
					pos+=1
				end
			end
	
			local splen = pos-pos0
			putnum(splen-1)
	
			if nopredict then
				-- values will all be >= 2
				while pos0 < pos do
					putnum(dat[pos0]-2)
					pos0+=1
				end
			end
	
			nopredict=not nopredict
		end
	
		if (bit!=1) dest+=1 -- flush
	
		return dest-dest0
	end
	
