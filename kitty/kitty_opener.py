import platform
import re
import subprocess
from pathlib import Path

# NOTE: Debug with this function and run (in dotfiles) `gal -g bash --force` and
# make the bash script `cat personal/random.txt`.
# def debug(text):
#     subprocess.run(f"echo '{text}' >> /home/david/code/dotfiles/personal/random.txt", shell=True)

symlink_extracting_regex = r": symbolic link to (.+)"

if platform.system() == "Linux":
    git_path = "/home/linuxbrew/.linuxbrew/bin/git"
else:
    git_path = "/fill/me/in/with/macos/git/path"


def is_file_or_symlink_to_file(path, cwd):
    file_check = subprocess.run(
        ["file", path],
        capture_output=True,
        text=True,
        cwd=cwd,
    )

    file_check_stdout = file_check.stdout

    if file_check.returncode == 0 and re.search(r"text", file_check_stdout):
        return True
    elif match := re.search(symlink_extracting_regex, file_check_stdout):
        symbolic_link_target = match.group(1)
        return is_file_or_symlink_to_file(symbolic_link_target, cwd)
    else:
        return False


def github_path(cwd):
    result = subprocess.run(
        [git_path, "remote", "-v"],
        capture_output=True,
        text=True,
        cwd=cwd,
    )
    match = re.search(r"origin.*github\.com:(.*)\.git", result.stdout)
    return match.group(1).strip() if match else "davidrunger/david_runger"


home = str(Path.home())
editor = f"{home}/code/dotfiles-personal/bin/editor"


regex = re.compile(
    r"\b(action=[^#\s]+#\S+)\b|(?:\b|\(|\s|^|/)([0-9a-f]{6,40}|#\d+)(?:\b|\))|((?:~|/|\b|\.)[^\s{}'\"]+/[^\s{}'\":]+(?::\d+){0,2}\b/?)"
)


def mark(text, args, Mark, extra_cli_args, *a):
    # This function is responsible for finding all
    # matching text. extra_cli_args are any extra arguments
    # passed on the command line when invoking the kitten.
    for idx, m in enumerate(re.finditer(regex, text)):
        # Iterate over each capturing group in the match
        for group_num in range(1, len(m.groups()) + 1):
            match_text = m.group(group_num)
            if match_text:
                start, end = m.span(group_num)
                mark_text = match_text.replace("\n", "").replace("\0", "")
                # Yield a Mark object for each non-empty match
                yield Mark(idx, start, end, mark_text, {})


def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    # This function is responsible for performing some
    # action on the selected text.
    chosen_text = data["match"][0]
    cwd = data["cwd"]

    if controller_action_match := re.match(
        r"^action=(?P<controller>[^#\s]+)#(?P<action>\S+)$", chosen_text
    ):
        controller = controller_action_match.group("controller")
        action = controller_action_match.group("action")
        controller_path = f"{cwd}/app/controllers/{controller}_controller.rb"

        line_match = None
        line_index = None

        with open(controller_path, "r") as file:
            lines = file.readlines()
            for index, line in enumerate(lines):
                match = re.search(r"^(?P<spaces> +)def {}\n".format(action), line)
                if match:
                    line_match = match
                    line_index = index
                    break

        if line_index is not None and line_match is not None:
            line_number = line_index + 1
            num_spaces = len(line_match.group("spaces"))
            column_number = num_spaces + 1
            path_with_line_and_col_numbers = "{}:{}:{}".format(
                controller_path, line_number, column_number
            )
            subprocess.run([editor, path_with_line_and_col_numbers], cwd=cwd)
    elif pr_number_match := re.match(r"^#(?P<pr_number>\d{1,6})$", chosen_text):
        # open PR with default browser
        pr_number = pr_number_match.group("pr_number")
        subprocess.run(
            ["xdg-open", f"https://github.com/{github_path(cwd)}/pull/{pr_number}"]
        )
    elif re.match(r"^([a-f0-9]{6,40})$", chosen_text):
        # open git sha with default browser
        subprocess.run(
            ["xdg-open", f"https://github.com/{github_path(cwd)}/commit/{chosen_text}"]
        )
    elif re.match(r"^http", chosen_text):
        # open HTTP URL with default browser
        subprocess.run(["xdg-open", chosen_text])
    else:
        path_without_suffix_numbers = re.sub(r"(:\d+){1,2}$", "", chosen_text)
        if is_file_or_symlink_to_file(path_without_suffix_numbers, cwd):
            # open with editor
            subprocess.run([editor, chosen_text], cwd=cwd)
        else:
            # open with OS default program for this file
            subprocess.run(["xdg-open", chosen_text], cwd=cwd)
