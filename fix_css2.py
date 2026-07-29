import sys

def replace_in_file(filepath, search, replace):
    with open(filepath, 'r') as f:
        content = f.read()
    if search in content:
        content = content.replace(search, replace)
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Replaced successfully in {filepath}")
    else:
        print(f"Search string not found in {filepath}")

search_css = """  .spotlight-card {
    position: absolute;
    top: -5px;
    left: 50%;
    transform: translate(-50%, -100%) scale(1.0);"""

replace_css = """  .spotlight-card {
    position: fixed;
    top: 12px;
    left: 50%;
    transform: translateX(-50%);"""

replace_in_file('/Users/matt/projects/qwerty-midi-hammerspoon/src/web/index.html', search_css, replace_css)
replace_in_file('/Users/matt/projects/qwerty-midi-hammerspoon/src/ui_html.lua', search_css, replace_css)
