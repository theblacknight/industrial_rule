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

fx.fov = love.graphics.newPixelEffect[[

extern vec2 supervisorNormal;
extern vec2 supervisorPos;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords) 
{
    float alpha = 1.0;
    vec2 toPixel = pixel_coords - supervisorPos;
    float angle =  acos(dot(supervisorNormal, normalize(toPixel)));
    if ( length(toPixel) < 250 && angle < 0.873f && angle > -0.873f ) 
    {
        vec4 col = texture2D(texture, texture_coords);
        return col * vec4(3.0, 1.2, 1.2, 0.8);
    }
    return texture2D(texture, texture_coords);
}


]]