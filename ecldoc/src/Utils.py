import os

def genPathTree(ecl_files, ext) :
    path_tree = { "root" : {} }
    for file in ecl_files :
        path = os.path.normpath(file.lower()).split(os.sep)
        parent = path_tree["root"]
        for ind, node in enumerate(path[:-1]) :
            if node not in parent :
                parent[node] = {}
            parent = parent[node]

        parent[path[-1] + ext] = file + ext

    return path_tree

