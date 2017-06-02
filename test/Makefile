SRCS := ${shell find -name '*.ecl'}
XMLS := ${SRCS:%.ecl=%.xml}

xmls : ${XMLS}
	echo done

%.xml : %.ecl
	~/eclcc -M $< > $@

clean :
	rm *.xml