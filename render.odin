package main

import "core:c"
import "core:math"
import rl "vendor:raylib"

// --- Colors ---

C_BG      :: rl.Color{10, 10, 26, 255}
C_GRID    :: rl.Color{20, 20, 55, 255}
C_PLAYER  :: rl.Color{0, 255, 255, 255}
C_PGLOW   :: rl.Color{0, 100, 100, 80}
C_SCOUT   :: rl.Color{255, 0, 255, 255}
C_TANK    :: rl.Color{255, 136, 0, 255}
C_SWARM   :: rl.Color{255, 255, 0, 255}
C_SNIPER  :: rl.Color{255, 50, 50, 255}
C_B_PLYR  :: rl.Color{0, 255, 200, 255}
C_B_ENMY  :: rl.Color{255, 80, 80, 255}
C_HUD     :: rl.Color{180, 220, 255, 255}
C_TITLE   :: rl.Color{0, 255, 255, 255}
C_MENU    :: rl.Color{150, 180, 220, 255}

// --- Background ---

draw_background :: proc() {
    rl.ClearBackground(C_BG)

    // parallax star layers
    t := f32(rl.GetTime())
    star_layers := [3]f32{0.3, 0.6, 1.0}
    for ly in star_layers {
        scroll := t * 30 * ly * (1 + g_level.scroll_spd/200)
        for i := 0; i < 40; i += 1 {
            ux := f32(cast(u32)rl.GetRandomValue(0, 80000)) / 100.0
            uy := f32(cast(u32)rl.GetRandomValue(0, 80000)) / 100.0 + scroll
            uy = math.mod(uy, 820)
            if uy < 0 { uy += 820 }
            bright := u8(80 + cast(u32)rl.GetRandomValue(0, 100))
            rl.DrawPixel(c.int(ux), c.int(uy), rl.Color{bright, bright, u8(100+cast(u32)rl.GetRandomValue(0,100)), 255})
        }
    }

    // scrolling grid lines
    gs := math.mod(t * g_level.scroll_spd * 0.5, 40)
    for gy := -gs; gy < 820; gy += 40 {
        rl.DrawLine(0, c.int(gy), 800, c.int(gy), C_GRID)
    }
    for gx: f32 = 0; gx <= 800; gx += 40 {
        rl.DrawLine(c.int(gx), 0, c.int(gx), 800, C_GRID)
    }

    // warp lines
    for i := 0; i < 3; i += 1 {
        wx := 150 + f32(i)*200 + math.sin(t*2 + f32(i))*40
        rl.DrawLineEx(v2(wx, 0), v2(wx+math.sin(t)*30, 800), 1.0, rl.Color{0, 40, 80, 120})
    }
}

// --- Player drawing ---

draw_player :: proc() {
    p := g_player
    if p.inv_t > 0 && cast(i32)(p.inv_t*10)%2 == 0 do return

    sz := PLAYER_SIZE

    // glow
    rl.BeginBlendMode(.ADDITIVE)
    for i_g := 0; i_g < 3; i_g += 1 {
        gs := sz * f32(1.5 + f32(i_g)*0.6)
        alpha := u8(40 - u8(i_g)*10)
        draw_triangle_glow(p.pos, gs, rl.Color{0, 150, 200, alpha})
    }
    rl.EndBlendMode()

    // main hull
    draw_triangle_ship(p.pos, sz, C_PLAYER, 1.2)

    // engine glow
    rl.BeginBlendMode(.ADDITIVE)
    rl.DrawCircleV(v2(p.pos.x, p.pos.y+sz*0.7), sz*0.25, rl.Color{255, 100, 0, 120})
    rl.EndBlendMode()

    // shield indicator
    if p.shield_t > 0 {
        rl.DrawRing(p.pos, sz*1.4, sz*1.6, 0, 360, 16, rl.Color{80, 140, 255, 180})
    }
}

draw_triangle_ship :: proc(center: rl.Vector2, size: f32, color: rl.Color, aspect: f32) {
    a1 := v2(center.x, center.y - size)
    a2 := v2(center.x - size*0.7, center.y + size*aspect*0.6)
    a3 := v2(center.x + size*0.7, center.y + size*aspect*0.6)
    rl.DrawTriangle(a1, a2, a3, color)
    // outline
    rl.DrawTriangleLines(a1, a2, a3, rl.Color{255, 255, 255, 60})
}

draw_triangle_glow :: proc(center: rl.Vector2, size: f32, color: rl.Color) {
    a1 := v2(center.x, center.y - size)
    a2 := v2(center.x - size*0.7, center.y + size*0.7)
    a3 := v2(center.x + size*0.7, center.y + size*0.7)
    rl.DrawTriangle(a1, a2, a3, color)
}

// --- Enemy drawing ---

draw_enemies :: proc() {
    for i in 0..<MAX_ENEMIES {
        e := &g_enemies[i]
        if !e.active do continue

        color := enemy_color(e.type)
        if e.flash_t > 0 {
            color = rl.WHITE
        }

        switch e.type {
        case .Scout:
            draw_rotated_diamond(e.pos, e.size, color, e.move_t*3)
        case .Tank:
            draw_hexagon(e.pos, e.size, color, e.move_t*0.5)
        case .Swarm:
            draw_triangle_ship(e.pos, e.size, color, 0.8)
        case .Sniper:
            draw_cross_shape(e.pos, e.size, color, e.move_t*1.5)
        }

        // hp bar for tanks
        if e.max_hp > 3 {
            bw := e.size * 2
            bh := f32(3)
            bx := e.pos.x - bw/2
            by := e.pos.y - e.size - 8
            rl.DrawRectangleV(v2(bx, by), v2(bw, bh), rl.Color{40,40,40,200})
            hp_frac := f32(e.hp) / f32(e.max_hp)
            bar_color := rl.Color{255, 100, 50, 255}
            if hp_frac > 0.5 { bar_color = rl.Color{255, 200, 50, 255} }
            rl.DrawRectangleV(v2(bx, by), v2(bw*hp_frac, bh), bar_color)
        }
    }

    // boss
    if g_level.boss_active {
        draw_boss_entity(&g_level.boss)
    }
}

draw_rotated_diamond :: proc(center: rl.Vector2, size: f32, color: rl.Color, rotation: f32) {
    points := [4]rl.Vector2{
        v2(center.x, center.y - size),
        v2(center.x + size*0.6, center.y),
        v2(center.x, center.y + size),
        v2(center.x - size*0.6, center.y),
    }
    cos_a := math.cos(rotation)
    sin_a := math.sin(rotation)
    for j in 0..<4 {
        px := points[j].x - center.x
        py := points[j].y - center.y
        points[j].x = center.x + px*cos_a - py*sin_a
        points[j].y = center.y + px*sin_a + py*cos_a
    }
    rl.DrawTriangle(points[0], points[1], points[2], color)
    rl.DrawTriangle(points[0], points[3], points[2], color)
    // glow
    rl.BeginBlendMode(.ADDITIVE)
    rl.DrawTriangle(points[0], points[1], points[2], rl.Color{color.r/2, color.g/2, color.b/2, 60})
    rl.DrawTriangle(points[0], points[3], points[2], rl.Color{color.r/2, color.g/2, color.b/2, 60})
    rl.EndBlendMode()
}

draw_hexagon :: proc(center: rl.Vector2, radius: f32, color: rl.Color, rotation: f32) {
    pts: [6]rl.Vector2
    for i in 0..<6 {
        a := rotation + f32(i)*60.0*rl.DEG2RAD
        pts[i] = v2(center.x + math.cos(a)*radius, center.y + math.sin(a)*radius)
    }
    for i in 0..<6 {
        rl.DrawTriangle(center, pts[i], pts[(i+1)%6], color)
    }
    rl.BeginBlendMode(.ADDITIVE)
    rl.DrawRing(center, radius-1, radius+1, 0, 360, 16, rl.Color{color.r/3, color.g/3, color.b/3, 70})
    rl.EndBlendMode()
}

draw_cross_shape :: proc(center: rl.Vector2, size: f32, color: rl.Color, rotation: f32) {
    w := size * 0.35
    h := size * 1.2
    rl.DrawRectanglePro({center.x-w/2, center.y-h/2, w, h}, {w/2, h/2}, rotation*rl.RAD2DEG, color)
    rl.DrawRectanglePro({center.x-h/2, center.y-w/2, h, w}, {h/2, w/2}, rotation*rl.RAD2DEG, color)
    rl.BeginBlendMode(.ADDITIVE)
    rl.DrawRectanglePro({center.x-w/2, center.y-h/2, w, h}, {w/2, h/2}, rotation*rl.RAD2DEG, rl.Color{color.r/2, color.g/2, color.b/2, 60})
    rl.EndBlendMode()
}

draw_boss_entity :: proc(b: ^Enemy) {
    sz := b.size
    pos := b.pos
    t := f32(rl.GetTime())

    color := rl.Color{255, 80, 60, 255}
    if b.flash_t > 0 { color = rl.WHITE }

    // outer ring
    rl.DrawRing(pos, sz-2, sz+2, 0, 360, 24, color)
    // rotating inner structure
    inner := sz * 0.55
    for i_arm := 0; i_arm < 4; i_arm += 1 {
        a := t*3 + f32(i_arm)*(math.PI/2)
        ex := pos.x + math.cos(a)*inner*0.5
        ey := pos.y + math.sin(a)*inner*0.5
        rl.DrawLineEx(v2(ex, ey), v2(pos.x+math.cos(a)*inner, pos.y+math.sin(a)*inner), 4, color)
        rl.DrawCircleV(v2(ex, ey), 5, rl.Color{255, 150, 50, 255})
    }
    // center eye
    rl.DrawCircleV(pos, sz*0.3, rl.Color{255, 255, 255, 200})
    rl.DrawCircleV(pos, sz*0.15, rl.Color{255, 200, 100, 150})

    // glow
    rl.BeginBlendMode(.ADDITIVE)
    rl.DrawCircleV(pos, sz*1.2, rl.Color{255, 80, 40, 40})
    rl.EndBlendMode()

    // hp bar
    if b.max_hp > 0 {
        bw := f32(300)
        bh := f32(8)
        bx := 400 - bw/2
        by := f32(16)
        rl.DrawRectangleV(v2(bx, by), v2(bw, bh), rl.Color{30,30,30,230})
        hp_frac := f32(b.hp) / f32(b.max_hp)
        rl.DrawRectangleV(v2(bx, by), v2(bw*hp_frac, bh), rl.Color{255, 60, 40, 255})
        rl.DrawRectangleLinesEx({bx, by, bw, bh}, 1, rl.Color{255, 255, 255, 80})
    }
}

// --- Bullets ---

draw_bullets :: proc() {
    for i in 0..<MAX_BULLETS {
        b := &g_bullets[i]
        if !b.active do continue

        if b.is_player {
            // trail
            rl.BeginBlendMode(.ADDITIVE)
            rl.DrawRectanglePro(
                {b.pos.x - b.size*0.8, b.pos.y - b.size*2, b.size*1.6, b.size*4},
                {b.size*0.8, b.size*2}, 0,
                rl.Color{b.color.r, b.color.g, b.color.b, 80},
            )
            rl.EndBlendMode()
            rl.DrawCircleV(b.pos, b.size, b.color)
        } else {
            rl.DrawCircleV(b.pos, b.size, b.color)
            rl.BeginBlendMode(.ADDITIVE)
            rl.DrawCircleV(b.pos, b.size*1.5, rl.Color{b.color.r, b.color.g, b.color.b, 100})
            rl.EndBlendMode()
        }
    }
}

// --- PowerUps ---

draw_powerups :: proc() {
    t := f32(rl.GetTime())
    for i in 0..<MAX_POWERUPS {
        pu := &g_powerups[i]
        if !pu.active do continue

        // glow
        rl.BeginBlendMode(.ADDITIVE)
        color := powerup_color(pu.type)
        rl.DrawCircleV(pu.pos, pu.size*1.6, rl.Color{color.r, color.g, color.b, 60})
        rl.EndBlendMode()

        // rotating diamond
        draw_rotated_diamond(pu.pos, pu.size, powerup_color(pu.type), t*6)

        // about to expire blink
        if pu.timer < 3 && cast(i32)(pu.timer*6)%2 == 0 do return
    }
}

powerup_color :: proc(t: PowerType) -> rl.Color {
    switch t {
    case .SpeedUp:    return {0, 255, 100, 255}
    case .TripleShot: return {255, 200, 0, 255}
    case .Shield:     return {100, 150, 255, 255}
    case .Bomb:       return {255, 50, 50, 255}
    case .Heal:       return {0, 220, 100, 255}
    case .WeaponUp:   return {180, 100, 255, 255}
    }
    return rl.WHITE
}

// --- Particles ---

draw_particles :: proc() {
    rl.BeginBlendMode(.ADDITIVE)
    for i in 0..<MAX_PARTICLES {
        p := &g_particles[i]
        if !p.active do continue
        alpha := u8(f32(p.color.a) * (p.life / p.max_life))
        col := rl.Color{p.color.r, p.color.g, p.color.b, alpha}
        rl.DrawCircleV(p.pos, p.size, col)
    }
    rl.EndBlendMode()
}

// --- HUD ---

draw_hud :: proc() {
    // top bar background
    rl.DrawRectangle(0, 0, 800, 36, rl.Color{5, 5, 15, 200})

    rl.DrawText(rl.TextFormat("SCORE %d", g_score), 10, 8, 18, C_HUD)
    rl.DrawText(rl.TextFormat("LIVES %d", g_player.lives), 200, 8, 18, rl.Color{255, 150, 150, 255})
    rl.DrawText(rl.TextFormat("BOMBS %d", g_player.bomb_count), 310, 8, 18, rl.Color{255, 200, 100, 255})
    rl.DrawText(rl.TextFormat("WPN %d", g_player.weapon_lvl), 450, 8, 18, rl.Color{200, 150, 255, 255})
    rl.DrawText(rl.TextFormat("LEVEL %d", g_level.number), 630, 8, 18, C_HUD)

    // active power-up indicators
    py: c.int = 42
    if g_player.speed_t > 0 {
        rl.DrawText("SPEED UP", 10, py, 14, rl.GREEN)
        py += 16
    }
    if g_player.triple_t > 0 {
        rl.DrawText("TRIPLE SHOT", 10, py, 14, rl.GOLD)
        py += 16
    }
    if g_player.shield_t > 0 {
        rl.DrawText("SHIELD", 10, py, 14, rl.SKYBLUE)
        py += 16
    }
}

// --- Menu ---

draw_menu :: proc() {
    rl.ClearBackground(C_BG)
    t := f32(rl.GetTime())

    // animated background
    for i := 0; i < 60; i += 1 {
        y := math.mod(f32(i)*13 + t*40, 820)
        if y < 0 { y += 820 }
        alpha := u8(30 + cast(u32)rl.GetRandomValue(0, 40))
        rl.DrawLine(0, c.int(y), 800, c.int(y), rl.Color{0, 80, 120, alpha})
    }

    // title
    tw := rl.MeasureText(cstring("GEO SHOOTER"), 48)
    rl.DrawText(cstring("GEO SHOOTER"), 400 - tw/2, 200, 48, C_TITLE)

    // decorative line
    rl.DrawLine(300, 260, 500, 260, C_PLAYER)
    rl.DrawLine(300, 262, 500, 262, rl.Color{0, 150, 150, 100})

    // menu items
    blink := cast(i32)(t*2)%2 == 0
    if blink {
        mw := rl.MeasureText(cstring("PRESS ENTER TO START"), 20)
        rl.DrawText(cstring("PRESS ENTER TO START"), 400 - mw/2, 330, 20, C_MENU)
    }

    cw := rl.MeasureText(cstring("WASD/Arrows : Move   J : Shoot   K : Special   L : Bomb"), 12)
    rl.DrawText(cstring("WASD/Arrows : Move   J : Shoot   K : Special   L : Bomb"), 400 - cw/2, 420, 12, rl.Color{100, 120, 160, 255})

    pw := rl.MeasureText(cstring("ESCAPE : Pause"), 12)
    rl.DrawText(cstring("ESCAPE : Pause"), 400 - pw/2, 440, 12, rl.Color{100, 120, 160, 255})

    // decorative shapes
    for i_shape := 0; i_shape < 5; i_shape += 1 {
        sx := 200 + f32(i_shape)*100
        sy := 500 + math.sin(t*2 + f32(i_shape))*20
        draw_rotated_diamond(v2(sx, sy), 14, rl.Color{0, 80, 120, 120}, t*3 + f32(i_shape))
    }
}

// --- Pause overlay ---

draw_pause_overlay :: proc() {
    rl.DrawRectangle(0, 0, 800, 800, rl.Color{0, 0, 0, 150})
    tw := rl.MeasureText(cstring("PAUSED"), 40)
    rl.DrawText(cstring("PAUSED"), 400 - tw/2, 350, 40, rl.WHITE)
    sw := rl.MeasureText(cstring("Press ESC to resume"), 16)
    rl.DrawText(cstring("Press ESC to resume"), 400 - sw/2, 400, 16, rl.Color{150, 150, 150, 255})
}

// --- Game Over ---

draw_game_over :: proc() {
    rl.ClearBackground(C_BG)
    t := f32(rl.GetTime())

    gw := rl.MeasureText(cstring("GAME OVER"), 44)
    rl.DrawText(cstring("GAME OVER"), 400 - gw/2, 280, 44, rl.Color{255, 80, 80, 255})

    sc := rl.TextFormat("FINAL SCORE: %d", g_score)
    sw := rl.MeasureText(sc, 22)
    rl.DrawText(sc, 400 - sw/2, 340, 22, C_HUD)

    if cast(i32)(t*2)%2 == 0 {
        rw := rl.MeasureText(cstring("PRESS ENTER TO RESTART"), 18)
        rl.DrawText(cstring("PRESS ENTER TO RESTART"), 400 - rw/2, 420, 18, C_MENU)
    }
}

// --- Level Complete ---

draw_level_complete :: proc() {
    rl.ClearBackground(C_BG)
    t := f32(rl.GetTime())

    lc := rl.TextFormat("LEVEL %d COMPLETE!", g_level.number)
    lw := rl.MeasureText(lc, 36)
    rl.DrawText(lc, 400 - lw/2, 280, 36, C_PLAYER)

    sc := rl.TextFormat("SCORE: %d", g_score)
    sw := rl.MeasureText(sc, 22)
    rl.DrawText(sc, 400 - sw/2, 340, 22, C_HUD)

    if cast(i32)(t*2)%2 == 0 {
        nw := rl.MeasureText(cstring("PRESS ENTER TO CONTINUE"), 18)
        rl.DrawText(cstring("PRESS ENTER TO CONTINUE"), 400 - nw/2, 420, 18, C_MENU)
    }
}
