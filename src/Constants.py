import os
code_dir = os.path.dirname(os.path.realpath(__file__))

TEMPLATE_DIR = os.path.join(code_dir, 'Templates')
HTML_TEMPLATE_DIR = os.path.join(TEMPLATE_DIR, 'html')
TXT_TEMPLATE_DIR = os.path.join(TEMPLATE_DIR, 'txt')
TEX_TEMPLATE_DIR = os.path.join(TEMPLATE_DIR, 'tex')