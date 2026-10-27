import unittest

from model import Config, Triangle, Vertex, rasterize_triangle


class RasterizeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = Config(width=8, height=8)

    def vertex(self, x: float, y: float) -> Vertex:
        return Vertex.from_pixels(x, y, config=self.config)

    def test_known_triangle_uses_pixel_centers_and_row_major_order(self) -> None:
        triangle = Triangle(
            self.vertex(1, 1),
            self.vertex(5, 1),
            self.vertex(1, 5),
            primitive_id=7,
        )

        pixels = rasterize_triangle(triangle, self.config)

        self.assertEqual(
            [(p.x, p.y) for p in pixels],
            [(1, 1), (2, 1), (3, 1), (1, 2), (2, 2), (1, 3)],
        )
        self.assertTrue(all(p.primitive_id == 7 for p in pixels))

    def test_degenerate_triangle_produces_no_pixels(self) -> None:
        triangle = Triangle(
            self.vertex(1, 1),
            self.vertex(3, 3),
            self.vertex(5, 5),
        )

        self.assertEqual(rasterize_triangle(triangle, self.config), [])

    def test_winding_normalization_preserves_coverage(self) -> None:
        ccw_in_screen = Triangle(self.vertex(1, 1), self.vertex(5, 1), self.vertex(1, 5))
        reversed_winding = Triangle(self.vertex(1, 1), self.vertex(1, 5), self.vertex(5, 1))

        self.assertEqual(
            rasterize_triangle(ccw_in_screen, self.config),
            rasterize_triangle(reversed_winding, self.config),
        )

    def test_top_left_rule_tiles_a_square_without_overlap(self) -> None:
        first = Triangle(self.vertex(1, 1), self.vertex(5, 1), self.vertex(1, 5))
        second = Triangle(self.vertex(5, 1), self.vertex(5, 5), self.vertex(1, 5))

        first_set = {(p.x, p.y) for p in rasterize_triangle(first, self.config)}
        second_set = {(p.x, p.y) for p in rasterize_triangle(second, self.config)}

        self.assertEqual(first_set & second_set, set())
        self.assertEqual(first_set | second_set, {(x, y) for y in range(1, 5) for x in range(1, 5)})

    def test_offscreen_triangle_is_clipped_to_framebuffer(self) -> None:
        triangle = Triangle(self.vertex(-2, -2), self.vertex(5, -2), self.vertex(-2, 5))

        pixels = rasterize_triangle(triangle, self.config)

        self.assertTrue(pixels)
        self.assertTrue(all(0 <= p.x < self.config.width for p in pixels))
        self.assertTrue(all(0 <= p.y < self.config.height for p in pixels))


if __name__ == "__main__":
    unittest.main()

