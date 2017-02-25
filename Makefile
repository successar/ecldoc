all :
	java -jar java-cup-11a.jar -dump ecl.cup
	java -jar jflex-1.6.1.jar ecl.flex
	javac -cp java-cup-11a.jar Lexer.java parser.java sym.java Main2.java Main.java

clean :
	rm *.class parser.java Lexer.java sym.java Lexer.java~

examples :
	java -cp "java-cup-11a.jar;." Main text.ecl > text.xml
	java -cp "java-cup-11a.jar;." Main example.ecl > example.xml

direc :
	java -cp "java-cup-11a.jar;." Main2 F:/ecl-samples-master

html :
	javac ToHTML.java
	java ToHTML text.xml text.html htmlstyle.xsl
	java ToHTML example.xml example.html htmlstyle.xsl

cleanexamples :
	rm text.xml example.xml text.html
