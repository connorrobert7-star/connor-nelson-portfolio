"""A hands-off run of the daily dungeon, for the coin-parity check.

The game (game/features/minigames/dungeon_overlay.gd) plays the same fight from the same
numbers in content/minigames/dungeon.json, plus the player's taps and the one item. This
simulation never taps, so it is the slowest a run can be. If a week with every bad omen
still clears all four rooms here, a saver and a non-saver earn the same coins.
"""

from dataclasses import dataclass, field

from backend.features.minigames.rules import content

DT = 0.05
REVIVE_FRACTION = 0.5


@dataclass
class Unit:
    kind: str
    x: float
    y: float
    hp: float
    max_hp: float
    dmg: float
    rate: float
    reach: float
    speed: float
    chips: int = 0
    drain: float = 0.0
    boss: bool = False
    radius: float = 0.0
    cd: float = 0.0
    down: float = 0.0
    extra: dict = field(default_factory=dict)

    @property
    def standing(self) -> bool:
        return self.hp > 0 and self.down <= 0

    def dist(self, other: "Unit") -> float:
        return ((self.x - other.x) ** 2 + (self.y - other.y) ** 2) ** 0.5

    def step_toward(self, other: "Unit", speed: float) -> None:
        d = self.dist(other)
        if d > 0:
            k = min(1.0, speed * DT / d)
            self.x += (other.x - self.x) * k
            self.y += (other.y - self.y) * k


def _party(mods: dict) -> list[Unit]:
    p = content("dungeon")["party"]
    hp = mods["party_hp"]
    dmg = p["buff_dmg"] if mods["buff"] else 1.0
    lead = p["leader"]
    spots = content("dungeon")["spots"]
    party = [
        Unit(
            "leader",
            *spots["leader"],
            lead["hp"] * hp,
            lead["hp"] * hp,
            lead["dmg"] * dmg,
            lead["rate"],
            lead["range"],
            lead["speed"],
        )
    ]
    f = p["follower"]
    for i in range(mods["followers"]):
        x, y = spots["followers"][i]
        party.append(
            Unit(
                "follower",
                x,
                y,
                f["hp"] * hp,
                f["hp"] * hp,
                f["dmg"] * dmg,
                f["rate"],
                f["range"],
                f["speed"],
            )
        )
    return party


def _enemies(room_index: int, mods: dict) -> list[Unit]:
    d = content("dungeon")
    names = list(d["rooms"][room_index]["enemies"])
    if mods["leech"] and room_index == d["leech_room"]:
        names.append("leech")
    out = []
    spots = d["spots"]
    y0, y1 = spots["enemy_y"]
    for i, name in enumerate(names):
        e = d["enemies"][name]
        out.append(
            Unit(
                name,
                spots["enemy_x"] + (i % 3) * 24.0,
                y0 + (i * 37 % (y1 - y0)),
                e["hp"],
                e["hp"],
                e["dmg"],
                e["rate"],
                e.get("slam_radius", d["melee"]),
                e["speed"],
                chips=e["chips"],
                drain=e.get("drain", 0.0),
                boss=e.get("boss", False),
                radius=e.get("slam_radius", 0.0),
                cd=e["rate"] if e.get("boss") else 0.0,
            )
        )
    return out


def _nearest(me: Unit, others: list[Unit]) -> Unit | None:
    alive = [o for o in others if o.standing]
    return min(alive, key=me.dist) if alive else None


def simulate_dungeon(mods: dict) -> dict:
    """Play the run with no taps. Returns rooms cleared, fight seconds used and chips per room."""
    d = content("dungeon")
    limit = d["fight_seconds"]
    down_s = d["party"]["down_s"]
    speed_k = mods["enemy_speed"]
    melee = d["melee"]
    t = 0.0
    rooms = 0
    chips_by_room: list[int] = []
    for room_index in range(len(d["rooms"])):
        party = _party(mods)  # everyone gets up and rests at each door
        enemies = _enemies(room_index, mods)
        chips = 0.0
        while any(e.hp > 0 for e in enemies) and t < limit:
            for m in party:
                if m.down > 0:
                    m.down -= DT
                    if m.down <= 0:
                        m.hp = m.max_hp * REVIVE_FRACTION
                    continue
                m.cd -= DT
                target = _nearest(m, enemies)
                if target is None:
                    break
                if m.dist(target) > m.reach:
                    if m.speed > 0:
                        m.step_toward(target, m.speed)
                elif m.cd <= 0:
                    m.cd = m.rate
                    target.hp -= m.dmg
                    if target.hp <= 0:
                        chips += target.chips
            for e in enemies:
                if e.hp <= 0:
                    continue
                e.cd -= DT * speed_k
                if e.drain:
                    chips = max(0.0, chips - e.drain * DT)
                target = _nearest(e, party)
                if target is None:
                    continue
                if e.dist(target) > (e.radius * 0.6 if e.boss else melee):
                    e.step_toward(target, e.speed * speed_k)
                elif e.cd <= 0:
                    e.cd = e.rate
                    hit = (
                        [m for m in party if m.standing and e.dist(m) <= e.radius]
                        if e.boss
                        else [target]
                    )
                    for m in hit:
                        m.hp -= e.dmg
                        if m.hp <= 0:
                            m.hp = 0
                            m.down = down_s
            t += DT
        if any(e.hp > 0 for e in enemies):
            break
        rooms += 1
        chips_by_room.append(round(chips))
    return {"rooms_cleared": rooms, "fight_seconds": round(t, 2), "chips": chips_by_room}
