all :
	java -jar java-cup-11a.jar ecl.cup
	java -jar jflex-1.6.1.jar ecl.flex
	javac -cp java-cup-11a.jar Lexer.java parser.java sym.java Main.java

clean :
	rm *.class parser.java Lexer.java sym.java Lexer.java~

examples :
	java -cp "java-cup-11a.jar;." Main text.ecl > text.xml
	java -cp "java-cup-11a.jar;." Main example.ecl > example.xml

cleanexamples :
	rm text.xml example.xml
