import re
import subprocess
from pathlib import Path

# NOTE: Debug with this function and run (in dotfiles) `gal -g bash --force` and
# make the bash script `cat personal/random.txt`.
# def debug(text):
#     subprocess.run(f"echo '{text}' >> /home/david/code/dotfiles/personal/random.txt", shell=True)

def github_path(cwd):
    result = subprocess.run(['git', 'remote', '-v'], capture_output=True, text=True, cwd=cwd)
    match = re.search(r'origin.*github\.com:(.*)\.git', result.stdout)
    return match.group(1).strip() if match else 'davidrunger/david_runger'

home = str(Path.home())
editor = f'{home}/code/dotfiles-personal/bin/editor'

def mark(text, args, Mark, extra_cli_args, *a):
    # This function is responsible for finding all
    # matching text. extra_cli_args are any extra arguments
    # passed on the command line when invoking the kitten.
    # We look for all paths (words containing a "/" that aren't HTTP URLs).
    regex = re.compile(r'(?:^|\b|\()([0-9a-f]{6,40}|#\d+)(?:\b|\)|$)|((?:~|/|\b|\.)[^\s#{}]+/[^\s:]+(?::\d+){0,2}\b/?)|(https?://\S+)')
    for idx, m in enumerate(re.finditer(regex, text)):
        # Iterate over each capturing group in the match
        for group_num in range(1, len(m.groups()) + 1):
            match_text = m.group(group_num)
            if match_text:
                start, end = m.span(group_num)
                mark_text = match_text.replace('\n', '').replace('\0', '')
                # Yield a Mark object for each non-empty match
                yield Mark(idx, start, end, mark_text, {})

def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    # This function is responsible for performing some
    # action on the selected text.
    chosen_text = data['match'][0]
    cwd = data['cwd']

    match = re.match(r'^#(?P<pr_number>\d{1,6})$', chosen_text)
    if match:
        # open PR with default browser
        pr_number = match.group('pr_number')
        subprocess.run(['xdg-open', f"https://github.com/{github_path(cwd)}/pull/{pr_number}"])
    elif re.match(r'^([a-f0-9]{7,40})$', chosen_text):
        # open git sha with default browser
        subprocess.run(['xdg-open', f"https://github.com/{github_path(cwd)}/commit/{chosen_text}"])
    elif re.match(r'^http', chosen_text):
        # open HTTP URL with default browser
        subprocess.run(['xdg-open', chosen_text])
    else:
        file_check = subprocess.run(['file', chosen_text], capture_output=True, text=True, cwd=cwd)
        if file_check.returncode == 0 and re.search(r'json|text', file_check.stdout):
            # open with editor
            subprocess.run([editor, chosen_text], cwd=cwd)
        else:
            # open with OS default program for this file
            subprocess.run(['xdg-open', chosen_text], cwd=cwd)