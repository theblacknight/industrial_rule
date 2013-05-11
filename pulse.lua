-- http://www.iquilezles.org/apps/shadertoy
-- Pulse glsl shader preset.
-- by Iñigo Quilez
-- adapted to Love by Ref

fx = {}
fx.pulseRed = love.graphics.newPixelEffect[[

extern number time;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    vec4 tex = texture2D(texture, texture_coords);
    return tex * vec4(min(3.0, tex.x + abs(tan(time))), 1.0, 1.0, 1.0);
}
]]

fx.pulseGreen = love.graphics.newPixelEffect[[

extern number time;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    return texture2D(texture, texture_coords) * vec4(1.0, 1.0 + abs(tan(time)), 1.0, 1.0);
}
]]