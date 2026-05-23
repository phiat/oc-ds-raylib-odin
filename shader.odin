package main

import rl "vendor:raylib"

BgShader :: struct {
    shader:  rl.Shader,
    loc_time: i32,
    loc_res:  i32,
    time:     f32,
}

load_bg_shader :: proc(w, h: i32) -> (s: BgShader) {
    s.shader = rl.LoadShader(nil, "shaders/background.fs")
    s.loc_time = rl.GetShaderLocation(s.shader, "u_time")
    s.loc_res = rl.GetShaderLocation(s.shader, "u_resolution")
    res := [2]f32{f32(w), f32(h)}
    rl.SetShaderValue(s.shader, s.loc_res, &res, .VEC2)
    return
}

update_bg_shader :: proc(s: ^BgShader) {
    s.time += rl.GetFrameTime()
    rl.SetShaderValue(s.shader, s.loc_time, &s.time, .FLOAT)
}

unload_bg_shader :: proc(s: ^BgShader) {
    rl.UnloadShader(s.shader)
}
