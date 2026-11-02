extends GutTest
# Example unit test
# Run tests via: Project -> Tools -> Gut panel (after enabling plugin)
# Or via CLI: godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit

func test_example_pass():
    assert_eq(1 + 1, 2, "Basic math should work")

func test_example_string():
    var text = "Hello"
    assert_eq(text.length(), 5, "String length should be 5")

func test_vector_operations():
    var vec = Vector2(3, 4)
    assert_almost_eq(vec.length(), 5.0, 0.01, "Vector magnitude should be 5")
