#version 300 es
// Voidline colour filter for blue-yellow (tritanopia).
// Daltonisation: works out what someone with this colour vision misses
// and moves that difference into colours they can tell apart.
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 c = texture(tex, v_texcoord);
    vec3 rgb = c.rgb;
    vec3 lms = vec3(
        17.8824 * rgb.r + 43.5161 * rgb.g + 4.11935 * rgb.b,
        3.45565 * rgb.r + 27.1554 * rgb.g + 3.86714 * rgb.b,
        0.0299566 * rgb.r + 0.184309 * rgb.g + 1.46709 * rgb.b);
    vec3 d = vec3(lms.x, lms.y, -0.395913 * lms.x + 0.801109 * lms.y);
    vec3 seen = vec3(
        0.0809444479 * d.x - 0.130504409 * d.y + 0.116721066 * d.z,
        -0.0102485335 * d.x + 0.0540193266 * d.y - 0.113614708 * d.z,
        -0.000365296938 * d.x - 0.00412161469 * d.y + 0.693511405 * d.z);
    vec3 missed = rgb - seen;
    vec3 shifted = vec3(0.0, 0.7 * missed.r + missed.g, 0.7 * missed.r + missed.b);
    fragColor = vec4(clamp(rgb + shifted, 0.0, 1.0), c.a);
}
