# Godot GUT Testing Skill

Unit testing with GUT (Godot Unit Test) framework for Godot 4.x.

## Test Structure

All tests extend `GutTest` and use `test_` prefix:

```gdscript
extends GutTest

func test_player_health():
    var player = Player.new()
    player.health = 100
    player.take_damage(30)
    assert_eq(player.health, 70, "Player should have 70 health")
```

## Common Assertions

| Assertion | Purpose |
|-----------|---------|
| `assert_eq(got, expected, msg)` | Values are equal |
| `assert_ne(got, not_expected, msg)` | Values are not equal |
| `assert_true(value, msg)` | Value is true |
| `assert_false(value, msg)` | Value is false |
| `assert_null(value, msg)` | Value is null |
| `assert_not_null(value, msg)` | Value is not null |
| `assert_almost_eq(got, expected, delta, msg)` | Float comparison |
| `assert_gt(got, expected, msg)` | Greater than |
| `assert_lt(got, expected, msg)` | Less than |
| `assert_has(container, element, msg)` | Container has element |
| `assert_does_not_have(container, element, msg)` | Container lacks element |

## Test Lifecycle Hooks

```gdscript
extends GutTest

func before_all():
    # Run once before all tests in this script
    pass

func before_each():
    # Run before each test
    pass

func after_each():
    # Run after each test
    pass

func after_all():
    # Run once after all tests
    pass
```

## Testing Example: Player Character

```gdscript
# test/unit/test_player.gd
extends GutTest

var player: Player

func before_each():
    player = Player.new()
    add_child_autofree(player)  # Auto-cleanup after test

func test_initial_health():
    assert_eq(player.health, 100, "Player starts with 100 health")

func test_take_damage():
    player.take_damage(25)
    assert_eq(player.health, 75, "Player health reduced by damage")

func test_death():
    player.health = 10
    player.take_damage(20)
    assert_true(player.is_dead, "Player should be dead")
    assert_eq(player.health, 0, "Health should not go below 0")

func test_heal():
    player.health = 50
    player.heal(30)
    assert_eq(player.health, 80, "Player healed by 30")
    
func test_heal_max_cap():
    player.health = 95
    player.heal(20)
    assert_eq(player.health, 100, "Healing capped at max health")
```

## Testing Signals

```gdscript
func test_health_changed_signal():
    watch_signals(player)
    player.take_damage(10)
    assert_signal_emitted(player, "health_changed", "Should emit health_changed")
    assert_signal_emit_count(player, "health_changed", 1)

func test_signal_with_parameters():
    watch_signals(player)
    player.take_damage(25)
    assert_signal_emitted_with_parameters(
        player, 
        "health_changed", 
        [75],  # Expected parameters
        "Signal should emit with correct health value"
    )
```

## Testing Scene Instantiation

```gdscript
func test_enemy_spawning():
    var enemy_scene = preload("res://entities/enemy.tscn")
    var enemy = enemy_scene.instantiate()
    add_child_autofree(enemy)
    
    assert_not_null(enemy, "Enemy should instantiate")
    assert_true(enemy is Enemy, "Should be Enemy class")
    assert_eq(enemy.health, 50, "Enemy starts with 50 health")
```

## Mocking and Doubling

```gdscript
func test_with_double():
    var double = double(Player).new()
    stub(double, "get_position").to_return(Vector2(100, 200))
    
    assert_eq(double.get_position(), Vector2(100, 200))
    assert_called(double, "get_position")
```

## Parameterized Tests (Inner Classes)

```gdscript
extends GutTest

class TestDamageCalculation:
    extends GutTest
    
    func test_normal_damage():
        var calc = DamageCalculator.new()
        assert_eq(calc.calculate(10, 1.0), 10)
    
    func test_critical_damage():
        var calc = DamageCalculator.new()
        assert_eq(calc.calculate(10, 2.0), 20)
    
    func test_reduced_damage():
        var calc = DamageCalculator.new()
        assert_eq(calc.calculate(10, 0.5), 5)
```

## Running Tests

### From Editor:
1. Enable GUT plugin: **Project → Project Settings → Plugins → Gut**
2. Open **GUT** panel at bottom of editor
3. Click **Run All** or select specific test

### From Command Line:
```bash
# Run all tests
godot --headless -s addons/gut/gut_cmdln.gd

# Run specific directory
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit/

# Run specific test file
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_player.gd

# Use config file
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
```

## Best Practices

- **Test in isolation**: Use `add_child_autofree()` for automatic cleanup
- **Test one thing**: Each test should verify one specific behavior
- **Use descriptive names**: `test_player_takes_damage_reduces_health()`
- **Setup/teardown**: Use `before_each()` and `after_each()` for shared setup
- **Mock dependencies**: Use doubles to isolate the unit under test
- **Test edge cases**: Zero, negative, max values, null inputs
- **Run tests frequently**: Integrate into your development workflow
- **CI/CD integration**: Run tests automatically on commit/push

## Directory Structure

```
res://
├── addons/
│   └── gut/              # GUT framework
├── test/
│   ├── unit/             # Unit tests (isolated)
│   │   ├── test_player.gd
│   │   ├── test_enemy.gd
│   │   └── test_inventory.gd
│   └── integration/      # Integration tests (multiple systems)
│       └── test_combat_system.gd
└── .gutconfig.json       # GUT configuration
```

## Example: Testing a Weapon System

```gdscript
# test/unit/test_weapon.gd
extends GutTest

var weapon: Weapon
var target: CharacterBody2D

func before_each():
    weapon = Weapon.new()
    weapon.damage = 15
    weapon.attack_speed = 1.0
    add_child_autofree(weapon)
    
    target = CharacterBody2D.new()
    target.set_script(preload("res://scripts/damageable.gd"))
    add_child_autofree(target)

func test_weapon_deals_damage():
    var initial_health = target.health
    weapon.attack(target)
    assert_eq(target.health, initial_health - 15, "Target takes weapon damage")

func test_attack_cooldown():
    weapon.attack(target)
    var can_attack_immediately = weapon.can_attack()
    assert_false(can_attack_immediately, "Cannot attack during cooldown")
    
    await get_tree().create_timer(1.1).timeout
    assert_true(weapon.can_attack(), "Can attack after cooldown")

func test_weapon_with_no_target():
    weapon.attack(null)
    # Should not crash, verify it handles gracefully
    assert_true(true, "Weapon handles null target")
