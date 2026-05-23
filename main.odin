package main

import "core:math"
import rl "vendor:raylib"

// --- Game State ---

GameState :: enum { Title, Playing, Paused, GameOver, LevelComplete }

g_state: GameState = .Title
g_bg_shader: BgShader

// --- Main ---

main :: proc() {
    rl.SetConfigFlags({.VSYNC_HINT})
    rl.InitWindow(800, 800, "Geo Shooter")
    rl.SetTargetFPS(60)
    rl.InitAudioDevice()

    g_bg_shader = load_bg_shader(800, 800)

    for !rl.WindowShouldClose() {
        update()
        draw()
    }

    unload_bg_shader(&g_bg_shader)
    rl.CloseAudioDevice()
    rl.CloseWindow()
}

update :: proc() {
    switch g_state {
    case .Title:
        if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
            start_level(1)
        }
    case .Playing:
        if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.P) {
            g_state = .Paused
            return
        }
        update_player()
        update_enemies()
        update_bullets()
        update_powerups()
        update_particles()
        update_level()

        if g_player.lives <= 0 {
            g_state = .GameOver
        }
        if g_level.boss_spawned && !g_level.boss_active && g_player.lives > 0 {
            g_state = .LevelComplete
        }
    case .Paused:
        if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.P) {
            g_state = .Playing
        }
    case .GameOver:
        if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
            start_level(1)
        }
    case .LevelComplete:
        if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
            start_level(g_level.number + 1)
        }
    }
}

draw :: proc() {
    // screen shake offset
    shake_x: f32 = 0
    shake_y: f32 = 0
    if g_screen_shake > 0 {
        shake_x = (f32(cast(u32)rl.GetRandomValue(0, 20000))/10000.0 - 1) * g_screen_shake * 8
        shake_y = (f32(cast(u32)rl.GetRandomValue(0, 20000))/10000.0 - 1) * g_screen_shake * 8
    }

    cam := rl.Camera2D{
        offset = {400, 400},
        target = {400 + shake_x, 400 + shake_y},
        rotation = 0,
        zoom = 1.0,
    }

    rl.BeginDrawing()

    switch g_state {
    case .Title:
        rl.BeginMode2D(cam)
        draw_menu()
        rl.EndMode2D()

    case .Playing, .Paused:
        update_bg_shader(&g_bg_shader)
        rl.BeginShaderMode(g_bg_shader.shader)
        rl.DrawRectangle(0, 0, 800, 800, rl.WHITE)
        rl.EndShaderMode()
        rl.BeginMode2D(cam)
        draw_enemies()
        draw_powerups()
        draw_bullets()
        draw_player()
        draw_particles()
        draw_hud()
        rl.EndMode2D()
        if g_state == .Paused {
            draw_pause_overlay()
        }

    case .GameOver:
        rl.BeginMode2D(cam)
        draw_game_over()
        rl.EndMode2D()

    case .LevelComplete:
        rl.BeginMode2D(cam)
        draw_level_complete()
        rl.EndMode2D()
    }

    rl.EndDrawing()
}

start_level :: proc(num: i32) {
    init_level(num)
    g_state = .Playing
}
