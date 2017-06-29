\chapter*{\VAR{name|escape_tex}}
\hypertarget{ecldoc:toc:\VAR{label}}{}

\BLOCK{ if bundle }
\BLOCK{ for tag in bundle.iterchildren() }
\VAR{ tag.tag|escape_tex } : \VAR{ tag.text|escape_tex } \\
\BLOCK{ endfor }
\BLOCK{ endif }

\section*{Table of Contents}
\BLOCK{ for d in files }
\VAR{ d.type|escape_tex } : \hyperlink{ecldoc:toc:\VAR{d.label}}{\VAR{ d.name|escape_tex }}  \VAR{ d.doc|escape_tex } \\
\BLOCK{ endfor }

\BLOCK{ for d in files }
\input{\VAR{ d.target[:-4] }}
\BLOCK{ endfor }
