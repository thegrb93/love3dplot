scrw, scrh, winmode = love.window.getMode()
class = require("middleclass")
hook = require("hook")
matrix = require("matrix")

local function norm(x)
    return x/math.sqrt(x[1][1]^2 + x[2][1]^2 + x[3][1]^2)
end
local function dot(x,y)
    return x[1][1]*y[1][1] + x[2][1]*y[2][1] + x[3][1]*y[3][1]
end
local function cross(x,y)
    return matrix{x[2][1]*y[3][1] - x[3][1]*y[2][1], x[3][1]*y[1][1] - x[1][1]*y[3][1], x[1][1]*y[2][1] - x[2][1]*y[1][1]}
end
local function inverttr(m)
    m[1][2], m[2][1] = m[2][1], m[1][2]
    m[1][3], m[3][1] = m[3][1], m[1][3]
    m[3][2], m[2][3] = m[2][3], m[3][2]
    local t = m * matrix{{m[1][4]},{m[2][4]},{m[3][4]},{0}}
    m[1][4] = -t[1][1]
    m[2][4] = -t[2][1]
    m[3][4] = -t[3][1]
    return m
end
local function fastmulvec(m, v, out)
    local a, b, c, d = v[1], v[2], v[3], v[4]
    out[1] = m[1][1]*a + m[1][2]*b + m[1][3]*c + m[1][4]*d
    out[2] = m[2][1]*a + m[2][2]*b + m[2][3]*c + m[2][4]*d
    out[3] = m[3][1]*a + m[3][2]*b + m[3][3]*c + m[3][4]*d
    out[4] = m[4][1]*a + m[4][2]*b + m[4][3]*c + m[4][4]*d
end
local function lerp(t, min, max)
    return min + t*(max - min)
end

local camera = class("camera")
function camera:initialize(fov, w, h, near, far)
    local fovscale = w*0.5/math.tan(math.rad(fov * 0.5))
    self.perspective = matrix{
        {fovscale, 0, -w/2, 0},
        {0, fovscale, -h/2, 0},
        {0, 0, -far / (far - near), -far*near / (far - near)},
        {0, 0, -1, 0},
    }
    
    self.model = matrix{
        {1, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 0, 1, 0},
        {0, 0, 0, 1},
    }
end
function camera:lookAt(pos, target, up)
    local forward = norm(target - pos)
    local right = norm(cross(up, forward))
    local up = cross(forward, right)
    self.model = matrix{
        {right[1][1], right[2][1], right[3][1], -dot(pos,right)},
        {up[1][1], up[2][1], up[3][1], -dot(pos,up)},
        {forward[1][1], forward[2][1], forward[3][1], -dot(pos,forward)},
        {0, 0, 0, 1},
    }
end
function camera:transform(vec, out)
    fastmulvec(self.model, vec, out)
    fastmulvec(self.perspective, out, out)
    out[1] = out[1] / out[4]
    out[2] = out[2] / out[4]
    out[3] = out[3] / out[4]
    return v
end

local linew = 0.001
local pointw = 4
local plot = class("plot")
function plot:initialize(minx, maxx, nx, miny, maxy, ny)
    local points, pointstf = {}, {}
    local xlines, xlinestf = {}, {}
    local ylines, ylinestf = {}, {}
    local xinc = (maxx - minx)/(nx - 1)
    local yinc = (maxy - miny)/(ny - 1)
    for i=1, nx*ny do
        local x = minx + ((i-1) % nx) * xinc
        local y = miny + math.floor((i-1) / nx) * yinc
        points[i] = {x, y, 0, 1}
        pointstf[i] = {}
    end
    for i=1, nx do
        local x = minx + (i-1) * xinc
        xlines[i*2-1] = {x, miny, 0, 1}
        xlines[i*2] = {x, maxy, 0, 1}
        xlinestf[i*2-1] = {}
        xlinestf[i*2] = {}
    end
    for i=1, ny do
        local y = miny + (i-1) * yinc
        ylines[i*2-1] = {minx, y, 0, 1}
        ylines[i*2] = {maxx, y, 0, 1}
        ylinestf[i*2-1] = {}
        ylinestf[i*2] = {}
    end
    
    self.points = points
    self.pointstf = pointstf
    self.xlines = xlines
    self.xlinestf = xlinestf
    self.ylines = ylines
    self.ylinestf = ylinestf

    self.centerx = (minx + maxx)/2
    self.centery = (miny + maxy)/2
    self.distance = math.max((maxx - minx)/2, (maxy - miny)/2)*2
    self.camera = camera:new(90, scrw, scrh, 0.1, 10000)
    self.t = 0
    self.dt = 1/60
end
function plot:drawGrid(points, pointstf)
    for i=1, #points, 2 do
        local pt1, pt2 = points[i], points[i+1]
        local pt1out, pt2out = pointstf[i], pointstf[i+1]
        self.camera:transform(pt1, pt1out)
        self.camera:transform(pt2, pt2out)
        love.graphics.line(pt1out[1], pt1out[2], pt2out[1], pt2out[2])
    end
end
local colormin = {1, 1, 1}
local colormax = {0.6745, 0.2039, 0.1412}
function plot:drawGraph()
    local minz, maxz = math.huge, -math.huge
    for k, v in ipairs(self.points) do
        minz = math.min(minz, v[3])
        maxz = math.max(maxz, v[3])
    end
    for k, v in ipairs(self.points) do
        local c
        if v[3]<0 then c = v[3]/minz else c = v[3]/maxz end
        local pt = self.pointstf[k]
        self.camera:transform(v, pt)
        love.graphics.setColor(lerp(c, colormin[1], colormax[1]), lerp(c, colormin[2], colormax[2]), lerp(c, colormin[3], colormax[3]))
        love.graphics.line(pt[1]-pointw/2, pt[2], pt[1]+pointw/2, pt[2])
    end
end
function plot:render()
    self.t = self.t + self.dt
    
    local theta = self.t*0.2
    self.camera:lookAt(matrix{self.centerx+self.distance*math.cos(theta), self.centery+self.distance*math.sin(theta), 0.4*self.distance}, matrix{self.centerx, self.centery, 0}, matrix{0, 0, 1})

    love.graphics.setLineWidth(linew)
    love.graphics.setColor(0.6, 0.6, 0.6)
    self:drawGrid(self.xlines, self.xlinestf)
    self:drawGrid(self.ylines, self.ylinestf)
    love.graphics.setLineWidth(pointw)
    self:drawGraph()
end

local minimizer = class("minimizer")
function minimizer:initialize(points, params, stepsize, calcError)
    self.points = points
    self.params = params
    self.lasterror = 0
    self.stepsize = stepsize
    self.calcError = calcError
    self.lasterror = self.calcError()
    self:calcPermutations()
end
-- function minimizer:calcPermutations()
    -- local permutations = {}
    -- local counter = {}
    -- for i=1, #self.params do
        -- counter[i] = 0
    -- end
    -- while true do
        -- local stop = true
        -- for i=1, #self.params do
            -- counter[i] = counter[i] + 1
            -- if counter[i] == 3 then
                -- counter[i] = 0
            -- else
                -- local perm = {}
                -- for j=1, #self.params do
                    -- if counter[j] == 0 then perm[j] = -self.stepsize
                    -- elseif counter[j] == 1 then perm[j] = 0
                    -- else perm[j] = self.stepsize end
                -- end
                -- permutations[#permutations+1] = perm
                -- stop = false
                -- break
            -- end
        -- end
        -- if stop then
            -- break
        -- end
    -- end
    -- self.stepperms = permutations
-- end
function minimizer:calcPermutations()
    local permutations = {}
    for i=1, #self.params do
        local perm1 = {}
        local perm2 = {}
        for j=1, #self.params do
            if i==j then
                perm1[j] = -self.stepsize
                perm2[j] = self.stepsize
            else
                perm1[j] = 0
                perm2[j] = 0
            end
        end
        permutations[#permutations+1] = perm1
        permutations[#permutations+1] = perm2
    end
    self.stepperms = permutations
end
function minimizer:step()
    if self.stepsize < 1e-5 then
        print("{"..table.concat(self.params, ", ").."}")
        self.step = function() end
    end
    --Find error that is less than current
    -- for _=1, 100 do
        local leasterr = self.lasterror
        local leastperm
        local original = {}
        for i, v in ipairs(self.params) do original[i] = v end

        for _, perm in ipairs(self.stepperms) do
            for i=1, #self.params do self.params[i] = original[i] + perm[i] end
            local err = self.calcError()
            if err < leasterr then
                leasterr = err
                leastperm = perm
            end
        end
        if leastperm then
            for i=1, #self.params do self.params[i] = original[i] + leastperm[i] end
            self.lasterror = leasterr
        else
            for i=1, #self.params do self.params[i] = original[i] end
            self.stepsize = self.stepsize * 0.5
            self:calcPermutations()
        end
    -- end
end

hook.add("postload","main",function()
    local p = plot:new(0, 10, 25, 0, 10, 25)
    local points = p.points
    local params = {0.775, 2.3555908203126, 0.995947265625, 2.6363159179688, 1.8569091796876, 1.124853515625, 0.6029052734375, 2.0859863281248, 0.86389160156257, 0.66158447265625, 1.0948242187494, 1.0421508789065, 0.19931640625, 2.123583984375, 0.88024902343751, -1.4717407226563, 1.1796875000001, 1.2220947265627}

    -- local function func(x, y)
        -- local param = params[1]
        -- return ((x+y)^3 - x^3 - y^3 - x^2*y*param - x*y^2*param) * 0.00001
    -- end

    -- local function func(x, y)
        -- local param = params[1]
        -- return ((x+y)^3 - x^3 - y^3 - 3*x^(3-param)*y^param - 3*x^param*y^(3-param)) * 0.00002
    -- end
    
    local function func(x, y)
        local z = (x+y)^math.pi - x^math.pi - y^math.pi
        for i=1, #params, 3 do
            local params1, params2, params3 = params[i], params[i+1], params[i+2]
            z = z - params1*(x^params3*y^params2 + x^params2*y^params3)
        end
        return z
    end

    -- local function func(x, y)
        -- local z = math.sqrt(x+y) - math.sqrt(x) - math.sqrt(y)
        -- for i=1, #params, 3 do
            -- local params1, params2, params3 = params[i], params[i+1], params[i+2]
            -- z = z - params1*(x^params2*y^params3 + x^params3*y^params2)
        -- end
        -- return z
    -- end

    local function calcError()
        local err = 0
        for _, v in ipairs(points) do
            local z = func(v[1], v[2])
            v[3] = z
            err = err + (z/(v[1]*v[2]+1)^2)^2
        end
        return err
    end

    local minimi = minimizer:new(points, params, 0.1, calcError)
    hook.add("render","rendering",function()
        minimi:step()
        p:render()
        love.graphics.setColor(1, 1, 1)
        
        local paramsStr = {}
        for k, v in ipairs(params) do
            paramsStr[k] = "Param"..k.." = " .. tostring(v).."\n"
        end
        love.graphics.print(paramsStr, 5, 5)
    end)
end)

function love.run()
    -- love.load(love.arg.parseGameArguments(arg), arg)
    hook.call("postload")

    -- Main loop time.
    return function()
        -- Process events.
        love.event.pump()
        for name,a,b,c,d,e,f in love.event.poll() do
            if name == "quit" then
                return a or 0
            end
            hook.call(name,a,b,c,d,e,f)
        end

        love.graphics.origin()
        love.graphics.clear(love.graphics.getBackgroundColor())
        hook.call("render")
        love.graphics.present()
    end
end
