all :
	java -jar java-cup-11a.jar -dump ecl.cup
	java -jar jflex-1.6.1.jar ecl.flex
	javac -cp java-cup-11a.jar Lexer.java parser.java sym.java Main.java

clean :
	rm *.class parser.java Lexer.java sym.java Lexer.java~

examples :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecldoc/test F:/ecldoc/test-xml xml
	java -cp "java-cup-11a.jar;." Main2 F:/ecldoc/test-xml F:/ecldoc/test-html html

cleanexamples :
	rm -r test-xml test-html *.xml *.html

direc :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecl-samples-master F:/ecl-samples-xml xml

cleandirec :
	rm -r F:/ecl-samples-xml F:/ecl-samples-html

direchtml :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecl-samples-xml F:/ecl-samples-html html


ml :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecl-ml-master F:/ecl-ml-xml xml

mlhtml :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecl-ml-xml F:/ecl-ml-html html

cleanml :
	rm -r F:/ecl-ml-xml F:/ecl-ml-html

testlex :
	java -jar jflex-1.6.1.jar ecl2.flex
	javac Lexer.java
	java Lexer bed.ecl

testbed :
	java -cp "java-cup-11a.jar;." Main F:/ecldoc/bed.ecl 
