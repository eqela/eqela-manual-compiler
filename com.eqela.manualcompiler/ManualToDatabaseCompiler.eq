
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

class ManualToDatabaseCompiler
{
	static bool create_tables(SQLDatabase db, Logger logger) {
		if(db.create_table("documents", LinkedList.create()
			.add(SQLTableColumnInfo.instance("id", SQLTableColumnInfo.TYPE_STRING))
			.add(SQLTableColumnInfo.instance("title", SQLTableColumnInfo.TYPE_STRING))
			.add(SQLTableColumnInfo.instance("type", SQLTableColumnInfo.TYPE_STRING))
			.add(SQLTableColumnInfo.instance("data", SQLTableColumnInfo.TYPE_TEXT))) == false) {
			Log.error("FAILED to create table: documents", logger);
			return(false);
		}
		if(db.create_index("documents", "id", true) == false) {
			Log.error("FAILED to create database index.", logger);
			return(false);
		}
		if(db.create_table("refs", LinkedList.create()
			.add(SQLTableColumnInfo.instance("documentid", SQLTableColumnInfo.TYPE_STRING))
			.add(SQLTableColumnInfo.instance("documenttitle", SQLTableColumnInfo.TYPE_STRING))
			.add(SQLTableColumnInfo.instance("referenceid", SQLTableColumnInfo.TYPE_STRING))
			.add(SQLTableColumnInfo.instance("referencetitle", SQLTableColumnInfo.TYPE_STRING))) == false) {
			Log.error("FAILED to create table: refs", logger);
			return(false);
		}
		if(db.create_index("refs", "documentid", false) == false) {
			Log.error("FAILED to create database index.", logger);
			return(false);
		}
		if(db.create_index("refs", "referenceid", false) == false) {
			Log.error("FAILED to create database index.", logger);
			return(false);
		}
		return(true);
	}

	public static bool compile(File source, File dest, Logger logger = null) {
		if(source == null || dest == null) {
			return(false);
		}
		if(source.is_directory() == false) {
			Log.error("Not a directory: `%s'".printf().add(source), logger);
			return(false);
		}
		if(dest.is_file()) {
			dest.remove();
		}
		if(dest.is_file()) {
			Log.error("FAILED to remove existing file: `%s'".printf().add(dest), logger);
			return(false);
		}
		var db = SQLiteDatabase.for_file(dest, true, logger);
		if(db == null) {
			Log.error("FAILED to initialize SQLite database: `%s'".printf().add(dest), logger);
			return(false);
		}
		if(create_tables(db, logger) == false) {
			return(false);
		}
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
				title = idxdoc.get_title();
				type = "index";
				data = JSONEncoder.encode(HashTable.create()
					.set("title", title)
					.set("description", idxdoc.get_description())
				);
				references = idxdoc.get_references();
			}
			else if(srcfile.has_extension("article")) {
				var rtd = RichTextWikiMarkupParser.parse_file(srcfile);
				if(rtd == null) {
					Log.error("FAILED to parse rich text document text file: `%s'".printf().add(srcfile), logger);
					return(false);
				}
				title = rtd.get_title();
				type = "article";
				var json = rtd.to_json();
				if(json != null) {
					references = json.get("references") as Collection;
					json.remove("references");
				}
				data = JSONEncoder.encode(json, false);
			}
			else {
				continue;
			}
			var sql = db.prepare("INSERT INTO documents (id, title, type, data) VALUES (?, ?, ?, ?);");
			if(sql == null) {
				Log.error("FAILED to prepare SQL statement.");
				return(false);
			}
			sql.add_param_str(id);
			sql.add_param_str(title);
			sql.add_param_str(type);
			sql.add_param_str(data);
			if(db.execute(sql) == false) {
				Log.error("Failed to insert document `%s' to database.".printf().add(id));
				return(false);
			}
			foreach(String reference in references) {
				var stmt = db.prepare("INSERT INTO refs (documentid, documenttitle, referenceid) VALUES (?, ?, ?);");
				if(stmt == null) {
					Log.error("FAILED to prepare SQL statement.");
					return(false);
				}
				stmt.add_param_str(id);
				stmt.add_param_str(title);
				stmt.add_param_str(reference);
				if(db.execute(stmt) == false) {
					Log.error("Failed to insert document reference.");
					return(false);
				}
			}
		}
		return(verify_references(db, logger));
	}

	static bool verify_references(SQLDatabase db, Logger logger) {
		var q = db.prepare("SELECT documentid, referenceid, referencetitle FROM refs;");
		if(q == null) {
			Log.error("FAILED to select reference IDs from database.", logger);
			return(false);
		}
		var rows = db.query(q);
		if(rows == null) {
			Log.error("FAILED to execute reference ID query.", logger);
			return(false);
		}
		foreach(HashTable row in db.query(q)) {
			var docid = row.get_string("documentid");
			var refid = row.get_string("referenceid");
			var title = row.get_string("referencetitle");
			if(String.is_empty(refid)) {
				Log.error("EMPTY reference ID for document `%s'".printf().add(docid), logger);
				return(false);
			}
			var qq = db.prepare("SELECT id, title FROM documents WHERE id = ?;");
			if(qq == null) {
				Log.error("FAILED to prepare SQL query.", logger);
				return(false);
			}
			qq.add_param_str(refid);
			var rr = db.query_single_row(qq);
			if(rr == null) {
				Log.error("Non-existing reference `%s' found in document `%s'".printf().add(refid).add(docid), logger);
				return(false);
			}
			if(String.is_empty(title)) {
				var ups = db.prepare("UPDATE refs SET referencetitle = ? WHERE referencetitle IS NULL AND referenceid = ?;");
				if(ups == null) {
					Log.error("FAILED to prepare UPDATE statement.", logger);
					return(false);
				}
				ups.add_param_str(rr.get_string("title"));
				ups.add_param_str(refid);
				if(db.execute(ups) == false) {
					Log.error("FAILED to update reference titles.");
					return(false);
				}
			}
		}
		return(true);
	}
}
