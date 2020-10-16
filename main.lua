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

    self.camera = camera:new(90, scrw, scrh, 0.1, 10000)
    self.font = love.graphics.newFont()
    self.paramtext = love.graphics.newText(self.font)
    self.t = 0
    self.dt = 1/60
    hook.add("render",self)
end
function plot:destroy()
    hook.remove("render",self)
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
        local z = self:func(v[1], v[2])
        minz = math.min(minz, z)
        maxz = math.max(maxz, z)
        v[3] = z
    end
    local zdiff = maxz - minz

    -- local zscale = 0.00001
    local zmax = math.max(math.abs(minz), math.abs(maxz))
    -- if zmax > 100 then
        -- zscale = 100 / zmax
    -- end

    for k, v in ipairs(self.points) do
        local c = math.abs(v[3])/zmax
        -- v[3] = v[3] * zscale
        local pt = self.pointstf[k]
        self.camera:transform(v, pt)
        love.graphics.setColor(lerp(c, colormin[1], colormax[1]), lerp(c, colormin[2], colormax[2]), lerp(c, colormin[3], colormax[3]))
        love.graphics.line(pt[1]-pointw/2, pt[2], pt[1]+pointw/2, pt[2])
    end
end
function plot:render()
    self.t = self.t + self.dt
    
    local theta = self.t*0.2
    local r = 130
    self.camera:lookAt(matrix{50+r*math.cos(theta), 50+r*math.sin(theta), 40}, matrix{50, 50, 0}, matrix{0, 0, 1})

    self.funcparam = math.sin(self.t)*1.4+1.5

    love.graphics.setLineWidth(linew)
    love.graphics.setColor(0.6, 0.6, 0.6, 0.6)
    self:drawGrid(self.xlines, self.xlinestf)
    self:drawGrid(self.ylines, self.ylinestf)
    love.graphics.setLineWidth(pointw)
    self:drawGraph()

    self.paramtext:set("Param = " .. tostring(self.funcparam))
    love.graphics.draw(self.paramtext, 5, 5)
end

hook.add("postload","main",function()
    local p = plot:new(0, 100, 50, 0, 100, 50)

    -- function p:func(x, y)
        -- local param = self.funcparam
        -- return ((x+y)^3 - x^3 - y^3 - x^2*y*param - x*y^2*param) * 0.00001
    -- end

    function p:func(x, y)
        local param = self.funcparam
        return ((x+y)^3 - x^3 - y^3 - 3*x^(3-param)*y^param - 3*x^param*y^(3-param)) * 0.00001
    end

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
