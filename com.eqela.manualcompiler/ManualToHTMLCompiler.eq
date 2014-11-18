
/*
 * This file is part of the Eqela Manual Compiler
 * Copyright (c) 2014 Eqela Pte Ltd
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

class ManualToHTMLCompiler
{
	public static bool compile(File source, File dest, Logger logger = null) {
		if(source == null || dest == null) {
			return(false);
		}
		if(source.is_directory() == false) {
			Log.error("Not a directory: `%s'".printf().add(source), logger);
			return(false);
		}
		if(dest.exists()) {
			Log.error("Destination directory already exists: `%s'".printf().add(dest), logger);
			return(false);
		}
		dest.mkdir_recursive();
		if(dest.is_directory() == false) {
			Log.error("FAILED to create destination directory: `%s'".printf().add(dest), logger);
			return(false);
		}
		var docs = HashTable.create();
		foreach(File srcfile in source.entries()) {
			var id = Path.strip_extension(srcfile.basename());
			if(String.is_empty(id)) {
				Log.error("Unable to determine document id from filename `%s'".printf().add(srcfile.basename()), logger);
				return(false);
			}
			String title, type, data;
			Collection references;
			if(srcfile.has_extension("index")) {
				var idxdoc = IndexDocument.for_file(srcfile);
				if(idxdoc == null) {
					Log.error("FAILED to parse index file: `%s'".printf().add(srcfile), logger);
					return(false);
				}
				docs.set(id, idxdoc);
			}
			else if(srcfile.has_extension("article")) {
				var rtd = RichTextWikiMarkupParser.parse_file(srcfile);
				if(rtd == null) {
					Log.error("FAILED to parse rich text document text file: `%s'".printf().add(srcfile), logger);
					return(false);
				}
				docs.set(id, rtd);
			}
			else {
				continue;
			}
		}
		if(dest.entry("style.css").set_contents_string(TEXTFILE("stylesheet.css")) == false) {
			Log.error("FAILED to write stylesheet.", logger);
			return(false);
		}
		foreach(String docid in docs) {
			var o = docs.get(docid);
			if(o == null) {
				continue;
			}
			if("main".equals(docid)) {
				docid = "index";
			}
			if(o is IndexDocument) {
				if(output_index_document(docid, (IndexDocument)o, dest, docs, logger) == false) {
					Log.error("FAILED to output document: `%s'".printf().add(docid), logger);
					return(false);
				}
			}
			else if(o is RichTextDocument) {
				if(output_rich_text_document(docid, (RichTextDocument)o, dest, docs, logger) == false) {
					Log.error("FAILED to output document: `%s'".printf().add(docid), logger);
					return(false);
				}
			}
			else {
				continue;
			}
		}
		return(true);
	}

	static bool output_index_document(String docid, IndexDocument doc, File destdir, HashTable docs, Logger logger) {
		var ff = destdir.entry(docid.append(".html"));
		var os = OutputStream.create(ff.write());
		if(os == null) {
			return(false);
		}
		os.println("<html>");
		os.println("<head>");
		os.println("<title>%s</title>".printf().add(doc.get_title()).to_string());
		os.println("<link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\" />");
		os.println("</head>");
		os.println("<body>");
		os.println("<h1>%s</h1>".printf().add(doc.get_title()).to_string());
		os.println("<p class=\"description\">%s</p>".printf().add(doc.get_description()).to_string());
		foreach(String ref in doc.get_references()) {
			String reftitle;
			var refo = docs.get(ref);
			if(refo is IndexDocument) {
				reftitle = ((IndexDocument)refo).get_title();
			}
			else if(refo is RichTextDocument) {
				reftitle = ((RichTextDocument)refo).get_title();
			}
			if(String.is_empty(reftitle)) {
				reftitle = ref;
			}
			os.println("<a class=\"linkparagraph\" href=\"%s.html\">%s</a>".printf().add(ref).add(reftitle).to_string());
		}
		os.println("</body>");
		return(true);
	}

	static bool output_rich_text_document(String docid, RichTextDocument doc, File destdir, HashTable docs, Logger logger) {
		var ff = destdir.entry(docid.append(".html"));
		var os = OutputStream.create(ff.write());
		if(os == null) {
			return(false);
		}
		os.println("<html>");
		os.println("<head>");
		os.println("<title>%s</title>".printf().add(doc.get_title()).to_string());
		os.println("<link rel=\"stylesheet\" type=\"text/css\" href=\"style.css\" />");
		os.println("</head>");
		os.println("<body>");
		foreach(RichTextParagraph paragraph in doc.get_paragraphs()) {
			if(paragraph is RichTextStyledParagraph) {
				var sp = (RichTextStyledParagraph)paragraph;
				var tag = "p";
				if("heading1".equals(sp.get_style())) {
					tag = "h1";
				}
				else if("heading2".equals(sp.get_style())) {
					tag = "h2";
				}
				else if("heading3".equals(sp.get_style())) {
					tag = "h3";
				}
				else if("heading4".equals(sp.get_style())) {
					tag = "h4";
				}
				else if("heading5".equals(sp.get_style())) {
					tag = "h5";
				}
				os.print("<%s>".printf().add(tag).to_string());
				foreach(RichTextSegment sg in sp.get_segments()) {
					if(String.is_empty(sg.get_link()) == false) {
						os.print("<a href=\"%s\">".printf().add(sg.get_link()).to_string());
					}
					var span = false;
					if(sg.get_bold() || sg.get_italic() || sg.get_underline() || String.is_empty(sg.get_color()) == false) {
						span = true;
						os.print("<span style=\"");
						if(sg.get_bold()) {
							os.print(" font-weight: bold;");
						}
						if(sg.get_italic()) {
							os.print(" font-style: italic;");
						}
						if(sg.get_underline()) {
							os.print(" text-decoration: underline;");
						}
						if(String.is_empty(sg.get_color()) == false) {
							os.print(" color: %s".printf().add(sg.get_color()).to_string());
						}
						os.print("\">");
					}
					os.print(sg.get_text());
					if(span) {
						os.print("</span>");
					}
					if(String.is_empty(sg.get_link()) == false) {
						os.print("</a>");
					}
				}
				os.println("</%s>".printf().add(tag).to_string());
			}
			else if(paragraph is RichTextPreformattedParagraph) {
				os.println("<div class=\"code\"><pre>%s</pre></div>".printf().add(((RichTextPreformattedParagraph)paragraph).get_text())
					.to_string());
			}
			else if(paragraph is RichTextLinkParagraph) {
				os.println("<a class=\"linkparagraph\" href=\"%s\">%s</a>".printf().add(((RichTextLinkParagraph)paragraph).get_url())
					.add(((RichTextLinkParagraph)paragraph).get_text()).to_string());
			}
			else {
				Log.warning("Unknown paragraph type encountered.");
			}
		}
		foreach(String ref in doc.get_references()) {
			String reftitle;
			var refo = docs.get(ref);
			if(refo is IndexDocument) {
				reftitle = ((IndexDocument)refo).get_title();
			}
			else if(refo is RichTextDocument) {
				reftitle = ((RichTextDocument)refo).get_title();
			}
			if(String.is_empty(reftitle)) {
				reftitle = ref;
			}
			os.println("<a class=\"reference\" href=\"%s.html\">%s</p>".printf().add(ref).add(reftitle).to_string());
		}
		os.println("</body>");
		return(true);
	}
}
