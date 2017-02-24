/*
  This example comes from a short article series in the Linux 
  Gazette by Richard A. Sevenich and Christopher Lopes, titled
  "Compiler Construction Tools". The article series starts at

  http://www.linuxgazette.com/issue39/sevenich.html

  Small changes and updates to newest JFlex+Cup versions 
  by Gerwin Klein
*/

/*
  Commented By: Christopher Lopes
  File Name: Main.java
  To Create: 
  After the scanner, lcalc.flex, and the parser, ycalc.cup, have been created.
  > javac Main.java
  
  To Run: 
  > java Main test.txt
  where test.txt is an test input file for the calculator.
*/
   
import java.io.*;
   
public class Main {
  static public void main(String argv[]) {    
    /* Start the parser */
    try {
      Lexer l = new Lexer(new FileReader(argv[0]));
      parser p = new parser(l);
      String result = (String) p.parse().value;      
      System.out.println("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<?xml-stylesheet type=\"text/xsl\" href=\"htmlstyle.xsl\"?>\n");
      System.out.println(result);
    } catch (Exception e) {
      /* do cleanup here -- possibly rethrow e */
      e.printStackTrace();
    }
  }
}


