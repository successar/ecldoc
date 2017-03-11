all :
	java -jar java-cup-11a.jar -dump ecl.cup
	java -jar jflex-1.6.1.jar ecl.flex
	javac -cp java-cup-11a.jar Lexer.java parser.java sym.java Main.java

clean :
	rm *.class parser.java Lexer.java sym.java Lexer.java~

testbed :
	java -cp "java-cup-11a.jar;." Main F:/ecldoc/bed.ecl 

examples :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecldoc/test F:/ecldoc/test-xml xml
	java -cp "java-cup-11a.jar;." Main2 F:/ecldoc/test-xml F:/ecldoc/test-html html

direc :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecl-samples-master F:/ecl-samples-xml xml

direchtml :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecl-samples-xml F:/ecl-samples-html html


cleanexamples :
	rm text.xml example.xml text.html

ml :
	javac -cp "java-cup-11a.jar;." ToHTML.java Main2.java
	java -cp "java-cup-11a.jar;." Main2 F:/ecl-ml-master F:/ecl-ml-xml xml

testlex :
	java -jar jflex-1.6.1.jar ecl2.flex
	javac Lexer.java
	java Lexer bed.ecl
