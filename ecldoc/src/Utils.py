import os
import re

def genPathTree(ecl_files, ext='') :
    path_tree = { "root" : {} }
    for file in ecl_files :
        path = os.path.normpath(file).split(os.sep)
        parent = path_tree["root"]
        for ind, node in enumerate(path[:-1]) :
            if node not in parent :
                parent[node] = {}
            parent = parent[node]

        if path[-1].lower() == 'bundle.ecl' :
            path[-1] = 'bundle.ecl'
        parent[path[-1]] = file + ext

    return path_tree

def getRoot(path_tree, ecl_file) :
    path = os.path.normpath(ecl_file).split(os.sep)[:-1]
    parent_path = ''
    parent = path_tree['root']
    for node in path :
        parent = parent[node]
        parent_path = os.path.join(parent_path, node)

    return parent


def breaksign(name, string) :
    name = name.lower()
    string = ' ' + string.lower() + ' '
    pos = 1
    open_bracks = ['{', '(', '[']
    close_bracks = ['}', ')', ']']
    stack = []
    for i in range(1, len(string)) :
        c = string[i]
        if c in open_bracks :
            stack.append(c)
        elif c in close_bracks :
            if stack[-1] == open_bracks[close_bracks.index(c)] :
                stack = stack[:-1]
            else :
                raise

        else :
            if len(stack) == 0 :
                m = re.match(r'[\s\)]' + name + r'([^0-9A-Za-z_])', string[pos-1:])
                if m :
                    return pos-1

        pos += 1

    return -1

LATEX_SUBS = (
    (re.compile(r'\\'), r'\\textbackslash '),
    (re.compile(r'([{}_#%&$])'), r'\\\1'),
    (re.compile(r'~'), r'\~{}'),
    (re.compile(r'\^'), r'\^{}'),
    (re.compile(r'"'), r"''"),
    (re.compile(r'\.\.\.+'), r'\\ldots'),
)

def escape_tex(value):
    newval = value
    for pattern, replacement in LATEX_SUBS:
        newval = pattern.sub(replacement, newval)
    return newval

def write_to_file(filename, text) :
    fp = open(filename, 'w')
    fp.write(text)
    fp.close()

def relpath(p1, p2) :
    return os.path.relpath(p1, p2)

def joinpath(*p1) :
    return os.path.join(*p1)

def dirname(p1) :
    return os.path.dirname(p1)