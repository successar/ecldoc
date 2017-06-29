\chapter*{\VAR{src.attrib['name']|escape_tex}}
\hypertarget{ecldoc:toc:\VAR{src.attrib.name}}{}

\section*{\underline{IMPORTS}}
\BLOCK{ if src.findall('./Import')|length > 0 }
\begin{itemize}
\BLOCK{ for imp in src.findall('./Import') }
\BLOCK{ if 'ref' in imp.attrib }
\item \VAR{ imp.attrib['ref']|escape_tex }
\BLOCK{ endif }
\BLOCK{ endfor }
\end{itemize}
\BLOCK{ endif }

\section*{\underline{DESCRIPTIONS}}
\BLOCK{ for def in render_dict recursive }
\subsection*{\VAR{(def.tag.find('./Type').text.upper() + ' : ' + def.tag.attrib.name)|escape_tex}}
\hypertarget{ecldoc:\VAR{def.tag.attrib.fullname}}{}
\begin{minipage}[t]{\textwidth}
\begin{flushleft}
\VAR{def['sign'].attrib['ret']|escape_tex} \VAR{def['sign'].attrib['name']|escape_tex} \VAR{def['sign'].attrib['param']|escape_tex}
\end{flushleft}
\end{minipage}
\hyperlink{ecldoc:\VAR{ def.up }}{Up}

\par
\BLOCK{ if 'content' in def['doc'] }
\BLOCK{ for line in def['doc']['content'] }
\VAR{ line }
\BLOCK{ endfor }
\BLOCK{ endif }
\par
\BLOCK{ for tag in def['doc']['tags'] }
\textbf{\VAR{tag[1]}} : \VAR{tag[0]|escape_tex} \\
\BLOCK{ endfor }
\BLOCK{ if def['defns']|length > 0 }
\begin{enumerate}
\BLOCK{ for child in def['defns'] }
\item \hyperlink{ecldoc:\VAR{child.tag.attrib.fullname}}{\VAR{ child.tag.attrib.name|escape_tex }}
\BLOCK{ endfor }
\end{enumerate}
\VAR{ loop(def['defns']) }
\BLOCK{ endif }
\BLOCK{ endfor }