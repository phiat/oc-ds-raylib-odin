package main

import "core:math"
import rl "vendor:raylib"

// --- Constants ---

MAX_BULLETS   :: 500
MAX_ENEMIES   :: 120
MAX_POWERUPS  :: 24
MAX_PARTICLES :: 2000

PLAYER_SIZE   :: f32(14)
PLAYER_SPEED  :: f32(320)
PLAYER_FIRE_RATE :: f32(0.14)
INVINCIBLE_TIME :: f32(1.5)

SCOUT_SCORE :: 100
TANK_SCORE  :: 250
SWARM_SCORE :: 50
SNIPER_SCORE :: 300
BOSS_SCORE  :: 5000

// --- Types ---

EnemyType :: enum { Scout, Tank, Swarm, Sniper }

Enemy :: struct {
    type:    EnemyType,
    pos:     rl.Vector2,
    vel:     rl.Vector2,
    hp:      i32,
    max_hp:  i32,
    size:    f32,
    active:  bool,
    fire_t:  f32,
    fire_r:  f32,
    move_t:  f32,
    move_a:  f32,
    flash_t: f32,
    score:   i32,
}

Bullet :: struct {
    pos:      rl.Vector2,
    vel:      rl.Vector2,
    active:   bool,
    is_player: bool,
    damage:   i32,
    size:     f32,
    color:    rl.Color,
}

PowerType :: enum { SpeedUp, TripleShot, Shield, Bomb, Heal, WeaponUp }

PowerUp :: struct {
    type:   PowerType,
    pos:    rl.Vector2,
    vel:    rl.Vector2,
    active: bool,
    size:   f32,
    timer:  f32,
}

Particle :: struct {
    pos:      rl.Vector2,
    vel:      rl.Vector2,
    color:    rl.Color,
    life:     f32,
    max_life: f32,
    size:     f32,
    active:   bool,
}

Player :: struct {
    pos:           rl.Vector2,
    vel:           rl.Vector2,
    hp:            i32,
    lives:         i32,
    shield:        f32,
    speed:         f32,
    fire_t:        f32,
    fire_r:        f32,
    special_t:     f32,
    weapon_lvl:    i32,
    inv_t:         f32,
    bomb_count:    i32,
    triple_t:      f32,
    speed_t:       f32,
    shield_t:      f32,
}

Level :: struct {
    number:     i32,
    scroll_spd: f32,
    elapsed:    f32,
    enemies_killed: i32,
    enemies_needed: i32,
    boss_spawned:   bool,
    boss:        Enemy,
    boss_active: bool,
    spawn_t:     f32,
    spawn_r:     f32,
    stage:       i32,
    stage_t:     f32,
}

// --- Global Pools ---

g_player: Player
g_enemies: [MAX_ENEMIES]Enemy
g_bullets: [MAX_BULLETS]Bullet
g_powerups: [MAX_POWERUPS]PowerUp
g_particles: [MAX_PARTICLES]Particle
g_level: Level
g_score: i32 = 0
g_screen_shake: f32 = 0.0

// --- Helpers ---

v2 :: proc(x, y: f32) -> rl.Vector2 { return {x, y} }
v2len :: proc(v: rl.Vector2) -> f32 { return math.sqrt(v.x*v.x + v.y*v.y) }
v2norm :: proc(v: rl.Vector2) -> rl.Vector2 {
    l := v2len(v); if l > 0 do return v2(v.x/l, v.y/l); return {}
}
v2dist :: proc(a, b: rl.Vector2) -> f32 { return v2len(v2(a.x-b.x, a.y-b.y)) }

rect_from_center :: proc(c: rl.Vector2, w, h: f32) -> rl.Rectangle {
    return {c.x - w/2, c.y - h/2, w, h}
}

aabb :: proc(ra, rb: rl.Rectangle) -> bool {
    return ra.x < rb.x + rb.width && ra.x + ra.width > rb.x &&
           ra.y < rb.y + rb.height && ra.y + ra.height > rb.y
}

// --- Player ---

init_player :: proc() {
    g_player = Player{
        pos = v2(400, 700),
        hp = 1,
        lives = 3,
        speed = PLAYER_SPEED,
        fire_r = PLAYER_FIRE_RATE,
        weapon_lvl = 1,
        bomb_count = 3,
    }
}

update_player :: proc() {
    p := &g_player
    dt := rl.GetFrameTime()

    // movement
    dx, dy: f32
    if rl.IsKeyDown(.A) || rl.IsKeyDown(.LEFT)   do dx -= 1
    if rl.IsKeyDown(.D) || rl.IsKeyDown(.RIGHT)  do dx += 1
    if rl.IsKeyDown(.W) || rl.IsKeyDown(.UP)     do dy -= 1
    if rl.IsKeyDown(.S) || rl.IsKeyDown(.DOWN)   do dy += 1

    mv := v2(dx, dy)
    if dx != 0 && dy != 0 { mv = v2(dx*0.707, dy*0.707) }
    speed := p.speed
    if p.speed_t > 0 { speed *= 1.5 }

    p.vel = v2(mv.x * speed, mv.y * speed)
    p.pos.x += p.vel.x * dt
    p.pos.y += p.vel.y * dt

    // clamp to screen
    p.pos.x = math.clamp(p.pos.x, 16, 800-16)
    p.pos.y = math.clamp(p.pos.y, 16, 800-16)

    // shooting
    p.fire_t -= dt
    if rl.IsKeyDown(.J) && p.fire_t <= 0 {
        fire_player_bullets()
        p.fire_t = p.fire_r
    }
    p.special_t -= dt
    if rl.IsKeyPressed(.K) && p.special_t <= 0 {
        fire_special()
        p.special_t = 0.6
    }
    if rl.IsKeyPressed(.L) && p.bomb_count > 0 {
        bomb()
        p.bomb_count -= 1
    }

    // power-up timers
    if p.triple_t > 0 { p.triple_t -= dt }
    if p.speed_t > 0  { p.speed_t -= dt }
    if p.shield_t > 0 { p.shield_t -= dt }

    // invincibility
    if p.inv_t > 0 { p.inv_t -= dt }

    // death check
    if p.hp <= 0 {
        p.lives -= 1
        if p.lives > 0 {
            p.pos = v2(400, 700)
            p.hp = 1
            p.inv_t = INVINCIBLE_TIME
            p.triple_t = 0
            p.speed_t = 0
            p.shield_t = 0
            p.weapon_lvl = 1
        }
    }
}

fire_player_bullets :: proc() {
    spd := f32(550)
    dmg := i32(1)
    clr := rl.Color{0, 255, 200, 255}
    sz  := f32(4)
    lvl := g_player.weapon_lvl

    if lvl >= 4 {
        offsets := [3]f32{0, -10, 10}
        for o in offsets {
            add_bullet(v2(g_player.pos.x + o, g_player.pos.y - 8), v2(0, -spd), true, dmg, sz, clr)
        }
    } else if lvl >= 2 {
        offsets := [2]f32{-6, 6}
        for o in offsets {
            add_bullet(v2(g_player.pos.x + o, g_player.pos.y - 8), v2(0, -spd), true, dmg, sz, clr)
        }
    } else {
        add_bullet(v2(g_player.pos.x, g_player.pos.y - 8), v2(0, -spd), true, dmg, sz, clr)
    }

    if g_player.triple_t > 0 {
        // extra side bullets with triple powerup
        add_bullet(v2(g_player.pos.x-14, g_player.pos.y-12), v2(-60, -spd*0.9), true, dmg, 3, rl.GOLD)
        add_bullet(v2(g_player.pos.x+14, g_player.pos.y-12), v2(60, -spd*0.9), true, dmg, 3, rl.GOLD)
    }
}

fire_special :: proc() {
    lvl := g_player.weapon_lvl
    clr := rl.Color{100, 200, 255, 255}
    count := 3 + lvl*2
    spread := f32(0.15 + f32(lvl)*0.05)
    for a := -spread; a <= spread; a += spread*2/f32(count) {
        vx := math.sin(a) * 450
        vy := -math.cos(a) * 550
        add_bullet(v2(g_player.pos.x, g_player.pos.y - 8), v2(vx, vy), true, 2, 5, clr)
    }
}

bomb :: proc() {
    // clear all enemy bullets and damage all enemies
    for i in 0..<MAX_BULLETS {
        if g_bullets[i].active && !g_bullets[i].is_player {
            g_bullets[i].active = false
        }
    }
    for i in 0..<MAX_ENEMIES {
        if g_enemies[i].active {
            g_enemies[i].hp -= 3
            if g_enemies[i].hp <= 0 {
                kill_enemy(i32(i))
            }
        }
    }
    spawn_explosion(g_player.pos, 100, 20, rl.Color{255, 200, 50, 255})
    g_screen_shake = 0.3
}

// --- Bullets ---

init_bullets :: proc() {
    for i in 0..<MAX_BULLETS {
        g_bullets[i].active = false
    }
}

add_bullet :: proc(pos, vel: rl.Vector2, is_player: bool, damage: i32, size: f32, color: rl.Color) {
    for i in 0..<MAX_BULLETS {
        if !g_bullets[i].active {
            g_bullets[i] = Bullet{pos=pos, vel=vel, active=true, is_player=is_player, damage=damage, size=size, color=color}
            return
        }
    }
}

update_bullets :: proc() {
    dt := rl.GetFrameTime()
    for i in 0..<MAX_BULLETS {
        b := &g_bullets[i]
        if !b.active do continue

        b.pos.x += b.vel.x * dt
        b.pos.y += b.vel.y * dt

        if b.pos.x < -20 || b.pos.x > 820 || b.pos.y < -20 || b.pos.y > 820 {
            b.active = false
        }
    }
}

update_bullet_collisions :: proc() {
    for i in 0..<MAX_BULLETS {
        b := &g_bullets[i]
        if !b.active do continue

        if b.is_player {
            rect := rect_from_center(b.pos, b.size*2, b.size*2)
            for j in 0..<MAX_ENEMIES {
                e := &g_enemies[j]
                if !e.active do continue
                erec := rect_from_center(e.pos, e.size*2, e.size*2)
                if aabb(rect, erec) {
                    b.active = false
                    e.hp -= b.damage
                    e.flash_t = 0.08
                    spawn_explosion(b.pos, 3, 3, b.color)
                    if e.hp <= 0 {
                        kill_enemy(i32(j))
                    }
                    break
                }
            }
        } else {
            if g_player.inv_t > 0 do continue
            rect := rect_from_center(b.pos, b.size*2, b.size*2)
            prec := rect_from_center(g_player.pos, PLAYER_SIZE*2, PLAYER_SIZE*2)
            if aabb(rect, prec) {
                b.active = false
                hurt_player()
            }
        }
    }
}

// --- Enemies ---

init_enemies :: proc() {
    for i in 0..<MAX_ENEMIES {
        g_enemies[i].active = false
    }
}

spawn_enemy :: proc(t: EnemyType, x, y: f32) -> ^Enemy {
    for i in 0..<MAX_ENEMIES {
        if !g_enemies[i].active {
            e := &g_enemies[i]
            e.type = t
            e.pos = v2(x, y)
            e.active = true
            switch t {
            case .Scout:  e.hp=2; e.max_hp=2; e.size=12; e.score=SCOUT_SCORE; e.fire_r=999
            case .Tank:   e.hp=5; e.max_hp=5; e.size=20; e.score=TANK_SCORE;  e.fire_r=1.8
            case .Swarm:  e.hp=1; e.max_hp=1; e.size=7;  e.score=SWARM_SCORE; e.fire_r=999
            case .Sniper: e.hp=3; e.max_hp=3; e.size=14; e.score=SNIPER_SCORE; e.fire_r=1.5
            }
            return e
        }
    }
    return nil
}

kill_enemy :: proc(idx: i32) {
    e := &g_enemies[idx]
    g_score += e.score
    g_level.enemies_killed += 1
    spawn_explosion(e.pos, 12, 8, enemy_color(e.type))

    // chance to drop power-up
    drop: f32 = 0.15
    if e.type == .Tank { drop = 0.4 }
    r := f32(cast(u32)rl.GetRandomValue(0, 1000)) / 1000.0
    if r < drop {
        pt := PowerType.SpeedUp
        rr := f32(cast(u32)rl.GetRandomValue(0, 1000)) / 1000.0
        switch {
        case rr < 0.3:  pt = .Heal
        case rr < 0.45: pt = .TripleShot
        case rr < 0.55: pt = .Shield
        case rr < 0.7:  pt = .Bomb
        case rr < 0.85: pt = .SpeedUp
        case:            pt = .WeaponUp
        }
        spawn_powerup(pt, e.pos)
    }

    e.active = false
}

enemy_color :: proc(t: EnemyType) -> rl.Color {
    switch t {
    case .Scout:  return {255, 0, 255, 255}
    case .Tank:   return {255, 136, 0, 255}
    case .Swarm:  return {255, 255, 0, 255}
    case .Sniper: return {255, 50, 50, 255}
    }
    return rl.WHITE
}

update_enemies :: proc() {
    dt := rl.GetFrameTime()
    for i in 0..<MAX_ENEMIES {
        e := &g_enemies[i]
        if !e.active do continue

        if e.flash_t > 0 { e.flash_t -= dt }
        e.move_t += dt
        e.fire_t -= dt

        switch e.type {
        case .Scout:
            e.vel.y = 120 + g_level.scroll_spd
            e.vel.x = math.sin(e.move_t * 3.0 + e.move_a) * 150
        case .Tank:
            target_y := f32(120 + f32(i%3)*80)
            if e.pos.y < target_y {
                e.vel.y = 60 + g_level.scroll_spd
                e.vel.x = math.sin(e.move_t * 1.5) * 40
            } else {
                e.vel.y = 0
                e.vel.x = math.sin(e.move_t * 1.2) * 60
                // shoot at player
                if e.fire_t <= 0 {
                    dir := v2norm(v2(g_player.pos.x - e.pos.x, g_player.pos.y - e.pos.y))
                    add_bullet(v2(e.pos.x, e.pos.y + 8), v2(dir.x*200, dir.y*200), false, 1, 4, rl.Color{255,80,80,255})
                    e.fire_t = e.fire_r
                }
            }
        case .Swarm:
            e.vel.y = 150 + g_level.scroll_spd
            e.vel.x = math.sin(e.move_t*5.0 + e.move_a)*80 + math.cos(e.move_t*3.3 + e.move_a)*60
        case .Sniper:
            e.vel.y = 40 + g_level.scroll_spd*0.3
            e.vel.x = (g_player.pos.x - e.pos.x) * 2.0
            if e.fire_t <= 0 && e.pos.y > 80 {
                add_bullet(v2(e.pos.x, e.pos.y+8), v2(0, 350), false, 1, 3, rl.Color{255,60,100,255})
                e.fire_t = e.fire_r
            }
        }

        // bounds - remove if off screen bottom
        e.pos.x += e.vel.x * dt
        e.pos.y += e.vel.y * dt
        if e.pos.y > 850 || e.pos.y < -100 || e.pos.x < -100 || e.pos.x > 900 {
            e.active = false
        }
        e.pos.x = math.clamp(e.pos.x, 8, 792)
    }

    // collision: enemy body vs player
    for i in 0..<MAX_ENEMIES {
        e := &g_enemies[i]
        if !e.active do continue
        if g_player.inv_t > 0 do continue

        erec := rect_from_center(e.pos, e.size*2, e.size*2)
        prec := rect_from_center(g_player.pos, PLAYER_SIZE*2, PLAYER_SIZE*2)
        if aabb(erec, prec) {
            hurt_player()
            e.hp -= 1
            if e.hp <= 0 { kill_enemy(i32(i)) }
        }
    }
}

hurt_player :: proc() {
    if g_player.inv_t > 0 do return
    if g_player.shield_t > 0 {
        g_player.shield_t = 0
        spawn_explosion(g_player.pos, 15, 6, rl.Color{100, 150, 255, 255})
        return
    }
    g_player.hp -= 1
    g_player.inv_t = INVINCIBLE_TIME
    g_screen_shake = 0.15
    spawn_explosion(g_player.pos, 8, 5, rl.Color{255, 100, 50, 255})
}

// --- PowerUps ---

init_powerups :: proc() {
    for i in 0..<MAX_POWERUPS {
        g_powerups[i].active = false
    }
}

spawn_powerup :: proc(t: PowerType, pos: rl.Vector2) {
    for i in 0..<MAX_POWERUPS {
        if !g_powerups[i].active {
            g_powerups[i] = PowerUp{type=t, pos=pos, vel=v2(0, 80), active=true, size=11, timer=10}
            return
        }
    }
}

update_powerups :: proc() {
    dt := rl.GetFrameTime()
    for i in 0..<MAX_POWERUPS {
        pu := &g_powerups[i]
        if !pu.active do continue

        pu.pos.y += pu.vel.y * dt
        pu.timer -= dt
        if pu.pos.y > 820 || pu.timer <= 0 {
            pu.active = false
            continue
        }

        prec := rect_from_center(g_player.pos, PLAYER_SIZE*2, PLAYER_SIZE*2)
        prec2 := rect_from_center(pu.pos, pu.size*2, pu.size*2)
        if aabb(prec, prec2) {
            apply_powerup(pu.type)
            pu.active = false
        }
    }
}

apply_powerup :: proc(t: PowerType) {
    switch t {
    case .SpeedUp:
        g_player.speed_t = 6.0
        spawn_explosion(g_player.pos, 6, 4, rl.GREEN)
    case .TripleShot:
        g_player.triple_t = 10.0
        spawn_explosion(g_player.pos, 6, 4, rl.GOLD)
    case .Shield:
        g_player.shield_t = 15.0
        spawn_explosion(g_player.pos, 8, 4, rl.SKYBLUE)
    case .Bomb:
        g_player.bomb_count += 1
        if g_player.bomb_count > 5 { g_player.bomb_count = 5 }
        spawn_explosion(g_player.pos, 6, 4, rl.RED)
    case .Heal:
        g_player.lives += 1
        if g_player.lives > 5 { g_player.lives = 5 }
        spawn_explosion(g_player.pos, 6, 4, rl.GREEN)
    case .WeaponUp:
        if g_player.weapon_lvl < 5 {
            g_player.weapon_lvl += 1
        }
        spawn_explosion(g_player.pos, 8, 4, rl.Color{180, 100, 255, 255})
    }
}

// --- Particles ---

init_particles :: proc() {
    for i in 0..<MAX_PARTICLES {
        g_particles[i].active = false
    }
}

spawn_explosion :: proc(pos: rl.Vector2, count: i32, speed: f32, color: rl.Color) {
    for _ in 0..<count {
        for i in 0..<MAX_PARTICLES {
            if !g_particles[i].active {
                angle := f32(cast(u32)rl.GetRandomValue(0, 6283)) / 1000.0
                spd := speed * (0.5 + f32(cast(u32)rl.GetRandomValue(0, 1000))/1000.0)
                life := 0.2 + f32(cast(u32)rl.GetRandomValue(0, 600))/1000.0
                g_particles[i] = Particle{
                    pos = pos,
                    vel = v2(math.cos(angle)*spd, math.sin(angle)*spd),
                    color = color,
                    life = life,
                    max_life = life,
                    size = 2.0 + f32(cast(u32)rl.GetRandomValue(0, 300))/100.0,
                    active = true,
                }
                break
            }
        }
    }
}

spawn_trail :: proc(pos: rl.Vector2, color: rl.Color) {
    for i in 0..<MAX_PARTICLES {
        if !g_particles[i].active {
            g_particles[i] = Particle{
                pos = pos,
                vel = v2(0, 0),
                color = color,
                life = 0.15,
                max_life = 0.15,
                size = 2.0,
                active = true,
            }
            return
        }
    }
}

update_particles :: proc() {
    dt := rl.GetFrameTime()
    for i in 0..<MAX_PARTICLES {
        p := &g_particles[i]
        if !p.active do continue

        p.life -= dt
        if p.life <= 0 {
            p.active = false
            continue
        }
        p.pos.x += p.vel.x * dt
        p.pos.y += p.vel.y * dt
        p.vel.x *= 0.96
        p.vel.y *= 0.96
    }
}

// --- Level / Boss ---

init_level :: proc(num: i32) {
    g_level = Level{
        number = num,
        scroll_spd = 80 + f32(num)*30,
        enemies_needed = 20 + num*10,
    }
    init_enemies()
    init_bullets()
    init_powerups()
    init_particles()
    init_player()
    g_score = 0
    g_screen_shake = 0
}

update_level :: proc() {
    l := &g_level
    dt := rl.GetFrameTime()
    l.elapsed += dt
    l.stage_t += dt

    // screen shake decay
    if g_screen_shake > 0 { g_screen_shake -= dt; if g_screen_shake < 0 { g_screen_shake = 0 } }

    // spawn waves
    if !l.boss_spawned {
        l.spawn_t -= dt
        if l.spawn_t <= 0 {
            spawn_enemy_wave(l)
            l.spawn_t = l.spawn_r
            l.spawn_r = math.max(0.3, 2.0 - f32(l.number)*0.3 - l.elapsed*0.02)
        }

        // check boss spawn
        if l.enemies_killed >= l.enemies_needed && !l.boss_spawned {
            spawn_boss(l)
        }
    } else if l.boss_active {
        update_boss(l)
    }

    update_bullet_collisions()
}

spawn_enemy_wave :: proc(l: ^Level) {
    count := 2 + i32(l.number)
    for _ in 0..<count {
        x := f32(cast(u32)rl.GetRandomValue(60, 740))
        y := f32(cast(u32)rl.GetRandomValue(-60, -20))
        r := f32(cast(u32)rl.GetRandomValue(0, 1000)) / 1000.0

        t: EnemyType
        switch {
        case r < 0.45: t = .Scout
        case r < 0.75: t = .Tank
        case r < 0.92: t = .Swarm
        case:           t = .Sniper
        }

        e := spawn_enemy(t, x, y)
        if e != nil {
            e.move_a = f32(cast(u32)rl.GetRandomValue(0, 6283)) / 1000.0
        }
    }

    // sometimes spawn swarm clusters
    if f32(cast(u32)rl.GetRandomValue(0, 1000))/1000.0 < 0.3 {
        cx := f32(cast(u32)rl.GetRandomValue(100, 700))
        for i_sw := 0; i_sw < 5; i_sw += 1 {
            e := spawn_enemy(.Swarm, cx + f32(i_sw-2)*18, -20)
            if e != nil {
                e.move_a = f32(i_sw) * 1.2
            }
        }
    }
}

spawn_boss :: proc(l: ^Level) {
    l.boss_spawned = true
    l.boss_active = true
    l.boss = Enemy{
        type = .Tank, // boss uses tank type, drawn differently
        pos = v2(400, -60),
        vel = v2(0, 0),
        hp = 20 + l.number*10,
        max_hp = 20 + l.number*10,
        size = 36,
        active = true,
        fire_r = 0.6,
    }
}

update_boss :: proc(l: ^Level) {
    b := &l.boss
    dt := rl.GetFrameTime()

    // enter screen
    if b.pos.y < 150 {
        b.pos.y += 60 * dt
    }

    // move side to side
    l.stage_t += dt
    b.pos.x = 400 + math.sin(l.stage_t * 0.8) * 200
    b.pos.y = 130 + math.sin(l.stage_t * 1.3) * 30

    // shooting patterns
    b.fire_t -= dt
    if b.fire_t <= 0 {
        // pattern: spiral or bursts
        pattern := i32(l.stage_t * 2.0) % 3
        switch pattern {
        case 0: // aimed shots
            for i_a := 0; i_a < 3; i_a += 1 {
                off := f32(i_a - 1) * 12
                dir := v2norm(v2(g_player.pos.x - (b.pos.x+off), g_player.pos.y - b.pos.y))
                add_bullet(v2(b.pos.x+off, b.pos.y+20), v2(dir.x*220, dir.y*220), false, 1, 5, rl.Color{255,60,60,255})
            }
        case 1: // circle burst
            for i_c := 0; i_c < 12; i_c += 1 {
                a := f32(i_c) * (math.PI*2/12) + l.stage_t*2
                add_bullet(v2(b.pos.x, b.pos.y+10), v2(math.cos(a)*180, math.sin(a)*180), false, 1, 4, rl.Color{255,150,50,255})
            }
        case 2: // fan spread
            for i_f := -4; i_f <= 4; i_f += 1 {
                a := f32(i_f) * 0.25
                add_bullet(v2(b.pos.x, b.pos.y+15), v2(math.sin(a)*250, math.cos(a)*300), false, 1, 4, rl.Color{255,200,100,255})
            }
        }
        b.fire_t = b.fire_r
    }

    // check boss bullets vs player handled in bullet_collisions
    // check boss vs player bullets
    brec := rect_from_center(b.pos, b.size*2.2, b.size*2.2)
    for i_bb in 0..<MAX_BULLETS {
        bb := &g_bullets[i_bb]
        if !bb.active || !bb.is_player do continue
        r := rect_from_center(bb.pos, bb.size*2, bb.size*2)
        if aabb(r, brec) {
            bb.active = false
            b.hp -= bb.damage
            b.flash_t = 0.06
            spawn_explosion(bb.pos, 3, 3, bb.color)
        }
    }

    if b.hp <= 0 {
        l.boss_active = false
        g_score += BOSS_SCORE
        spawn_explosion(b.pos, 60, 25, rl.RED)
        spawn_explosion(v2(b.pos.x-20, b.pos.y-10), 30, 15, rl.ORANGE)
        spawn_explosion(v2(b.pos.x+20, b.pos.y+10), 30, 15, rl.YELLOW)
        g_screen_shake = 0.5
    }
}
