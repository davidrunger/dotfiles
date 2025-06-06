import unittest
from kitty.kitty_opener import regex


class TestRegex(unittest.TestCase):
    def test_regex(self):
        test_cases = [
            ["format=html action=logs#index status=200", ["action=logs#index"]],
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
            [
                "File: /home/david/code/david_runger/ruby.rb",
                ["/home/david/code/david_runger/ruby.rb"],
            ],
            ["./personal/typescript.ts", ["./personal/typescript.ts"]],
            [
                '{:locations=>{"./spec/bin/open_pr_in_browser_spec.rb"=>[19]}}',
                ["./spec/bin/open_pr_in_browser_spec.rb"],
            ],
            [
                "{:locations=>{'./spec/bin/open_pr_in_browser_spec.rb'=>[19]}}",
                ["./spec/bin/open_pr_in_browser_spec.rb"],
            ],
            [
                "(https://davidrunger.com/#projects?query=string)",
                ["https://davidrunger.com/#projects?query=string"],
            ],
            [
                "bin/flag-unacked-file-versions:115:in `ack_data",
                ["bin/flag-unacked-file-versions:115"],
            ],
            [
                "RunFeatureTests : rspec ./spec/features/quizzes_spec.rb:9 # Quizzes app / when",
                ["./spec/features/quizzes_spec.rb:9"],
            ],
            [
                "![image](https://github.com/user-attachments/assets/c9dd2b93-9bd9-4c59-b6eb-9b3533285c7b)",
                [
                    "https://github.com/user-attachments/assets/c9dd2b93-9bd9-4c59-b6eb-9b3533285c7b"
                ],
            ],
        ]

        for input_text, expected_matches in test_cases:
            with self.subTest(input_text=input_text):
                matches = regex.findall(input_text)
                # Flatten the list of tuples to a single list of matches and filter out empty strings
                matches = [item for sublist in matches for item in sublist if item]
                self.assertEqual(matches, expected_matches)


if __name__ == "__main__":
    unittest.main()
