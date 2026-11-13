"""Regression checks for authored content, not just answers copied from the DOM."""

import copy
import math
from pathlib import Path
import tempfile
import unittest

from tools.advanced_content import lessons
from tools.build_course import DATA
from tools.check_course import PageInfo, check_link, check_structure, contrast
from tools.core_expansion import CORE
from tools.course_data import advanced_quiz, numeric_answer, parse_rows, validate_content
from tools.expanded_fields import EXTRA, FIELDS, PROJECTS


ROOT = Path(__file__).resolve().parents[1]


class ContentValidationTests(unittest.TestCase):
    def setUp(self):
        self.tables = [
            parse_rows(DATA, 20, optional=2),
            parse_rows(FIELDS, 5),
            lessons() + parse_rows(EXTRA, 13, optional=2),
            parse_rows(CORE, 14, optional=2),
            parse_rows(PROJECTS, 7),
        ]

    def test_authored_tables_are_valid(self):
        validate_content(*self.tables)

    def test_column_error_reports_source_and_line(self):
        with self.assertRaisesRegex(ValueError, "example:2"):
            parse_rows("00|one\n01|two|extra", 2, source="example")
        with self.assertRaisesRegex(ValueError, "empty content"):
            parse_rows(" \n", 2)

    def test_nonfinite_or_missing_answers_are_rejected(self):
        for value in (None, "", " ", "nan", "inf", "-inf", "1e309", "not a number",
                      "1_000", "١٢", "0x10", 1.0):
            with self.subTest(value=value), self.assertRaises(ValueError):
                numeric_answer(value, "test quiz")

    def test_composite_quiz_requires_all_three_parts(self):
        for value in ("question::1", "question::1::", "question::nan::solution", "::1::solution"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                advanced_quiz(value, "test quiz")

    def test_advanced_quiz_cannot_silently_become_derivation(self):
        row = self.tables[3][0]
        row[-2], row[-1] = row[-1], ""
        with self.assertRaisesRegex(ValueError, "derivation column"):
            validate_content(*self.tables)

    def test_duplicate_field_is_rejected(self):
        self.tables[1].append(copy.deepcopy(self.tables[1][0]))
        with self.assertRaisesRegex(ValueError, "field id"):
            validate_content(*self.tables)

    def test_duplicate_lesson_is_rejected(self):
        self.tables[3].append(copy.deepcopy(self.tables[3][0]))
        with self.assertRaisesRegex(ValueError, "lesson title"):
            validate_content(*self.tables)

    def test_missing_quiz_is_rejected(self):
        self.tables[3][0].pop()
        with self.assertRaisesRegex(ValueError, "missing advanced quiz"):
            validate_content(*self.tables)

    def test_unknown_field_or_stage_is_rejected(self):
        for index, value in ((0, "99"), (1, "unknown stage")):
            tables = copy.deepcopy(self.tables)
            tables[3][0][index] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_content(*tables)


class PhysicsAnswerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rows = {row[2]: [row[0]] + row[2:] for row in parse_rows(CORE, 14, optional=2)}

    def answer(self, title, advanced=False):
        row = self.rows[title]
        return float(row[14].split("::")[1] if advanced else row[8])

    def test_taylor_relative_error_divides_by_true_value(self):
        expected = (0.2 / math.sin(0.2) - 1) * 100
        self.assertAlmostEqual(self.answer("泰勒展开与量级估计", True), round(expected, 2))

    def test_coherence_length_converts_nanometers_to_micrometers(self):
        self.assertEqual(self.answer("相干长度与傅里叶光学", True), 500 ** 2 / 0.1 / 1000)

    def test_rutherford_uses_inverse_half_angle_to_fourth_power(self):
        ratio = (math.sin(math.radians(15)) / math.sin(math.radians(45))) ** 4
        self.assertEqual(self.answer("卢瑟福散射与核的发现"), round(ratio, 4))
        self.assertLess(ratio, 1)

    def test_instrument_resolution_is_full_uniform_interval(self):
        value = 0.02 / math.sqrt(12)
        self.assertEqual(self.answer("计量、溯源与系统误差", True), round(value, 4))

    def test_fine_structure_scale_has_correct_power_of_ten(self):
        row = self.rows["精细结构、塞曼效应与 21 cm 线"]
        self.assertIn("10⁻⁵", row[14].split("::")[0])
        self.assertTrue(math.isclose(self.answer(row[1], True) * 1e-5, (1 / 137) ** 2, rel_tol=.01))

    def test_variance_and_gaussian_convolution(self):
        self.assertIn("σ²/2", self.rows["概率、期望与涨落"][12])
        self.assertIn("σ/√2", self.rows["概率、期望与涨落"][12])
        self.assertEqual(self.answer("谱线展宽的三重来源与 Voigt 线型", True), 1)

    def test_nematic_full_mathematical_range(self):
        self.assertEqual(self.answer("软物质深化：液晶、聚合物、玻璃与主动物质"), (3 * 0 ** 2 - 1) / 2)

    def test_binary_reflex_speed_and_rigid_earth_wobble(self):
        self.assertEqual(self.answer("双星与质量测定", True), round(.000955 * 13100, 1))
        self.assertEqual(self.answer("惯量张量与三维转动：主轴、欧拉方程与进动", True), round(1 / .00328))

    def test_dispersion_force_differentiates_the_potential(self):
        self.assertIn("F_R=−6C₆/R⁷", self.rows["分子间力：色散、偶极与氢键"][4])
        self.assertEqual(self.answer("分子间力：色散、偶极与氢键", True), 7)

    def test_schwarzschild_thin_disk_efficiency(self):
        self.assertEqual(self.answer("吸积与 X 射线双星", True), round((1 - math.sqrt(8 / 9)) * 100, 1))

    def test_grover_iteration_reaches_first_probability_peak(self):
        title = "量子算法初探：Deutsch–Jozsa 与 Grover"
        for n, advanced in ((256, False), (10000, True)):
            with self.subTest(n=n):
                theta = math.asin(1 / math.sqrt(n))
                iterations = int(self.answer(title, advanced))
                self.assertEqual(iterations, math.floor(math.pi / (4 * theta)))
                probability = lambda r: math.sin((2 * r + 1) * theta) ** 2
                self.assertGreater(probability(iterations), probability(iterations - 1))
                self.assertGreater(probability(iterations), probability(iterations + 1))


class StructuralTests(unittest.TestCase):
    def test_bilingual_manifests_match_real_pages_and_quizzes(self):
        manifests, _, infos, _ = check_structure(ROOT)
        self.assertEqual(sum(len(info.answers) for info in infos.values()),
                         2 * sum(m["lesson_count"] for m in manifests.values()))

    def test_query_and_encoded_fragment_are_resolved(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder).resolve()
            file = root / "index.html"
            file.write_text('<h1 id="lesson one">Example</h1>', encoding="utf-8")
            info = {file: PageInfo(file.read_text(encoding="utf-8"))}
            check_link(root, file, "index.html?mode=1#lesson%20one", False, info)
            with self.assertRaisesRegex(ValueError, "missing fragment"):
                check_link(root, file, "#missing", False, info)
            with self.assertRaisesRegex(ValueError, "leaves repository"):
                check_link(root, file, "../outside.html", False, info)

    def test_remote_assets_are_rejected_but_reference_links_are_allowed(self):
        file = ROOT / "index.html"
        check_link(ROOT, file, "https://example.com/reading", False, {})
        for url in ("https://example.com/script.js", "//example.com/style.css"):
            with self.subTest(url=url), self.assertRaisesRegex(ValueError, "must be local"):
                check_link(ROOT, file, url, True, {})

    def test_contrast_detects_the_original_white_on_white_regression(self):
        self.assertEqual(contrast("rgb(255, 255, 255)", "rgb(255, 255, 255)"), 1)
        self.assertAlmostEqual(contrast("rgb(0, 0, 0)", "rgb(255, 255, 255)"), 21)


if __name__ == "__main__":
    unittest.main()
