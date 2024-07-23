import unittest
from kitty.kitty_opener import regex as compiled_pattern


class TestRegex(unittest.TestCase):
    def test_regex(self):
        test_cases = [
            ["abc123/#864", ["abc123", "#864"]],
            ["#86/abcd1234", ["#86", "abcd1234"]],
            ["Fix the thing [GROC-23] (#930)", ["#930"]],
            [
                "Go to https://davidrunger.com and http://davidrunger.com/",
                ["https://davidrunger.com", "http://davidrunger.com/"],
            ],
            [
                "284fe332513b2fabfc3ea6082201ba5f4edac08b",
                ["284fe332513b2fabfc3ea6082201ba5f4edac08b"],
            ],
            [
                "284fe",
                [],
            ],
            [
                "284fe332513b2fabfc3ea6082201ba5f4edac08b1",
                [],
            ],
            ["~/code/david_runger safe ✔ 03:45:56", ["~/code/david_runger"]],
            ["File: /home/david/code/david_runger/ruby.rb", ["/home/david/code/david_runger/ruby.rb"]],
            ["./personal/typescript.ts", ["./personal/typescript.ts"]],
        ]

        for input_text, expected_matches in test_cases:
            with self.subTest(input_text=input_text):
                matches = compiled_pattern.findall(input_text)
                # Flatten the list of tuples to a single list of matches and filter out empty strings
                matches = [item for sublist in matches for item in sublist if item]
                self.assertEqual(matches, expected_matches)


if __name__ == "__main__":
    unittest.main()
