import java.io.*;
   
public class Main2 {
  public static void walk( String path ) {

        File root = new File( path );
        File[] list = root.listFiles();

        if (list == null) return;

        for ( File f : list ) {
            if ( f.isDirectory() ) {
                walk( f.getAbsolutePath() );
            }
            else {
                try {
                  System.out.println( "File:" + f.getAbsoluteFile() );
                  if(f.getAbsolutePath().matches(".*ecl")) {
                    Lexer l = new Lexer(new FileReader(f.getAbsoluteFile()));
                    parser p = new parser(l);
                    String result = (String) p.parse().value;      
                    System.out.println(result);
                    System.out.println("");
                }
                } catch (Exception e) {
                  /* do cleanup here -- possibly rethrow e */
                  e.printStackTrace();
                }
            }
        }
    }

  static public void main(String argv[]) {    
    walk(argv[0]);
  }
}


