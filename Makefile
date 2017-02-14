all :
	bison -d ecl.y
	flex ecl.l
	g++ -std=gnu++11 ecl.tab.c lex.yy.c -lfl -o ecl
