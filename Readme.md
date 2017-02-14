To run the program :
1) make
2) ./ecl <ecl-file-name> > <output-xml-file-name>

eg : ./ecl example.ecl > example.xml

Similar code using jlex/cup can be generated in java, if required for the project.

ecl.l -> flex file for scanning

ecl.y -> bison file for parsing

ecl.tab.* -> files generated by running bison

lex.yy.c -> file generated from flex