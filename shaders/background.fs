#version 330

in vec2 fragTexCoord;
out vec4 finalColor;

uniform float u_time;
uniform vec2 u_resolution;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void main() {
    vec2 uv = fragTexCoord;

    // Stars - twinkling based on position
    float star = hash(floor(uv * 80.0));
    float twinkle = sin(u_time * 2.0 + star * 6.28) * 0.5 + 0.5;
    float starBright = step(0.997, star) * (0.3 + 0.7 * twinkle);

    // Grid lines scrolling downward
    float scrollY = uv.y + u_time * 0.15;
    float gridH = abs(sin(scrollY * 18.0)) * 0.6;
    float gridV = abs(sin(uv.x * 18.0)) * 0.3;
    float grid = max(gridH, gridV) * 0.15;

    // Subtle warp pattern
    float warp = sin(uv.y * 8.0 + u_time * 0.8 + sin(uv.x * 5.0) * 2.0) * 0.03;

    // Combine
    vec3 bgCol = vec3(0.04, 0.04, 0.10);
    vec3 gridCol = vec3(0.08, 0.08, 0.22);
    vec3 starCol = vec3(0.6, 0.6, 0.9);

    vec3 color = bgCol;
    color += gridCol * grid;
    color += starCol * starBright;
    color += vec3(0.02, 0.02, 0.06) * warp;

    finalColor = vec4(color, 1.0);
}
