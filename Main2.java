import java.io.*;
import java.util.Scanner;

public class Main2 {
	
	interface GenFile {
		public void gen(File f, String outpath, String[] args);
		public void genDir(File dir);
	}

	static class GenXML implements GenFile {
		public void gen(File f, String outpath, String[] args) {
			try {
				System.out.println( "File:" + outpath + "/" + f.getName() + ".xml " + f.getAbsoluteFile() );
				if(f.getAbsolutePath().matches(".*ecl")) {
					Lexer l = new Lexer(new FileReader(f.getAbsoluteFile()));
					parser p = new parser(l);
					String result = (String) p.parse().value;  
					PrintWriter writer = new PrintWriter(outpath + "/" + f.getName().replaceAll("(.*)ecl", "$1") + "xml", "UTF-8");
					writer.println(result);
					writer.close();    
				}
			} catch (Exception e) {
				e.printStackTrace();
				System.exit(0);	
			}
		}

		public void genDir(File dir) {}
	}

	static class GenHTML implements GenFile {
		public void gen(File f, String outpath, String[] args) {
			try {
				System.out.println( "File:" + outpath + "/" + f.getName() + ".html " + f.getAbsoluteFile() );
				if(f.getAbsolutePath().matches(".*xml")) {
					ToHTML.xsl(f.getAbsoluteFile().toString(), outpath + "/" + f.getName().replaceAll("(.*)xml", "$1") + "html", args[0]);
				}
			} catch (Exception e) {
				e.printStackTrace();
			}
		}

		public void genDir(File dir) {
			File[] list = dir.listFiles();
			try {
				PrintWriter writer = new PrintWriter(dir.getAbsolutePath() + "/" + "toc.html", "UTF-8");
				writer.println("<html><head><title>index</title></head>");
				writer.println("<body><ul>");
				for ( File f : list ) {
					if(f.isDirectory()) {
						writer.println("<li><a href = \"" + f.getName() + "/toc.html" + "\">" + f.getName() + "</a></li>");
					}
					else {
						if (f.getName() != "toc.html") writer.println("<li><a href = \"" + f.getName() + "\">" + f.getName() + "</a></li>");	
					}
				}
				writer.println("</ul></body>");
				writer.println("</html>");
				writer.close();
			}
			catch(Exception e) {
				e.printStackTrace();
			}
		}
	}

	public static void walk( String path, String outpath, GenFile generator, String[] args ) {

		File root = new File( path );
		File[] list = root.listFiles();

		if (list == null) return;

		File direc = new File(outpath); 
		if (!direc.exists()) direc.mkdir();

		for ( File f : list ) {
			if ( f.isDirectory() ) {
				walk( f.getAbsolutePath(), outpath + "/" + f.getName(), generator, args );
			}
			else {
				generator.gen(f, outpath, args);
			}
		}

		generator.genDir(direc);
	}

	static public void main(String argv[]) {  
		if (argv[2].equals("html")) { 
			String[] kwargs = { "htmlstyle.xsl" };
			GenFile generator = new GenHTML();
			walk(argv[0], argv[1], generator, kwargs);
		}
		else {
			String[] kwargs = { };
			GenFile generator = new GenXML();
			walk(argv[0], argv[1], generator, kwargs);
		}
	}
}


