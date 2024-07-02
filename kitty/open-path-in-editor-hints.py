import re
import subprocess

# NOTE: Debug with something like this:
#   subprocess.run(f"echo '{str(data)}' > /home/david/Downloads/data.txt", shell=True)

def mark(text, args, Mark, extra_cli_args, *a):
    # This function is responsible for finding all
    # matching text. extra_cli_args are any extra arguments
    # passed on the command line when invoking the kitten.
    # We look for all paths (words containing a "/" that aren't HTTP URLs).
    regex = r'(?:^|\s)(?!https?)(\S+/\S+)(?:\s|$)'
    for idx, m in enumerate(re.finditer(regex, text)):
        start, end = m.span(1)
        mark_text = text[start:end].replace('\n', '').replace('\0', '')
        # The empty dictionary below will be available as groupdicts
        # in handle_result() and can contain string keys and arbitrary JSON
        # serializable values.
        yield Mark(idx, start, end, mark_text, {})


def handle_result(args, data, target_window_id, boss, extra_cli_args, *a):
    # This function is responsible for performing some
    # action on the selected text.
    # matches is a list of the selected entries and groupdicts contains
    # the arbitrary data associated with each entry in mark() above
    matches, groupdicts = [], []
    for m, g in zip(data['match'], data['groupdicts']):
        if m:
            matches.append(m), groupdicts.append(g)
    for word, match_data in zip(matches, groupdicts):
        subprocess.run(f'editor {word}', shell=True, cwd=data['cwd'])
