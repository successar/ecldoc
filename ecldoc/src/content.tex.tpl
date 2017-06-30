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

{\renewcommand{\arraystretch}{1.5}
\begin{tabularx}{\textwidth}{|>{\raggedright\arraybackslash}l|X|}
\hline
\hspace{0pt}\VAR{def['sign'].attrib['ret']|escape_tex} & \VAR{def['sign'].attrib['name']|escape_tex} \\
\hline
\BLOCK{ if def['sign'].attrib['param'] != '' }
\multicolumn{2}{|>{\raggedright\arraybackslash}X|}{\hspace{0pt}\VAR{def['sign'].attrib['param']|escape_tex}} \\
\hline
\BLOCK{ endif }
\end{tabularx}
}

\hyperlink{ecldoc:\VAR{ def.up }}{Up}

\par
\BLOCK{ if 'content' in def['doc'] }
\BLOCK{ for line in def['doc']['content'] }
\VAR{ line }
\BLOCK{ endfor }
\BLOCK{ endif }

\BLOCK{ if def['doc']['tags']|length > 0 }
\par
\begin{description}
\BLOCK{ for tag in def['doc']['tags'] }
\item [\textbf{\VAR{tag[1]}}] \VAR{tag[0]|escape_tex}
\BLOCK{ endfor }
\end{description}
\BLOCK{ endif }

\BLOCK{ if def['defns']|length > 0 }
\begin{enumerate}
\BLOCK{ for child in def['defns'] }
\item \hyperlink{ecldoc:\VAR{child.tag.attrib.fullname}}{\VAR{ child.tag.attrib.name|escape_tex }}
\BLOCK{ endfor }
\end{enumerate}

\rule{\textwidth}{0.4pt}

\VAR{ loop(def['defns']) }

\BLOCK{ else }
\rule{\textwidth}{0.4pt}
\BLOCK{ endif }
\BLOCK{ endfor }