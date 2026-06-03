import os
import re

replacements = {
    "StudyHabit": "StudyHabit",
    "studyhabit": "studyhabit",
    "Study Habit": "Study Habit",
    "STUDYHABIT": "STUDYHABIT"
}

def process_file(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
    except UnicodeDecodeError:
        return # Skip binary files

    new_content = content
    for old, new in replacements.items():
        new_content = new_content.replace(old, new)

    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

def main():
    exclude_dirs = {'.git', 'build', 'node_modules', 'dist', '.dart_tool', 'windows/flutter/ephemeral', 'windows/x64'}
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if d not in exclude_dirs]
        for file in files:
            if file.endswith(('.png', '.jpg', '.jpeg', '.ico', '.pdf', '.exe', '.zip', '.msix', '.dll', '.so', '.dylib', '.sqlite')):
                continue
            filepath = os.path.join(root, file)
            process_file(filepath)

if __name__ == "__main__":
    main()
