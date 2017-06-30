\chapter*{\VAR{name|escape_tex}}
\hypertarget{ecldoc:toc:\VAR{label}}{}

\BLOCK{ if bundle }
\begin{tabularx}{\textwidth}{|l|X|}
\hline
\BLOCK{ for tag in bundle.iterchildren() }
\VAR{ tag.tag|escape_tex } & \VAR{ tag.text|escape_tex } \\
\hline
\BLOCK{ endfor }
\end{tabularx}
\BLOCK{ endif }

\section*{Table of Contents}
{\renewcommand{\arraystretch}{1.5}
\begin{longtable}{|p{\textwidth}|}
\hline
\BLOCK{ for d in files }
\hyperlink{ecldoc:toc:\VAR{d.label}}{\VAR{ d.name|escape_tex }} \\
\BLOCK{ if d.doc != '' }
\VAR{ d.doc|escape_tex } \\
\BLOCK{ endif }
\hline
\BLOCK{ endfor }
\end{longtable}
}

\BLOCK{ for d in files }
\input{\VAR{ d.target[:-4] }}
\BLOCK{ endfor }
