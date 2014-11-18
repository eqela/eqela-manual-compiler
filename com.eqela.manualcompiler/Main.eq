
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

public class Main : CommandLineApplication
{
	File source;
	File dest;
	String type;
	
	public void on_usage(UsageInfo ui) {
		ui.add_parameter("<source>", "The source directory");
		ui.add_parameter("<dest>", "The destination path (file / directory)");
		ui.add_flag("html", "Output an HTML document");
		ui.add_flag("db", "Output an SQLite database");
	}

	public bool on_command_line_flag(String flag) {
		if("html".equals(flag)) {
			type = "html";
			return(true);
		}
		if("db".equals(flag)) {
			type = "db";
			return(true);
		}
		return(base.on_command_line_flag(flag));
	}

	public bool on_command_line_option(String key, String value) {
		return(base.on_command_line_option(key, value));
	}

	public bool on_command_line_parameter(String param) {
		if(source == null) {
			source = File.for_native_path(param);
			return(true);
		}
		if(dest == null) {
			dest = File.for_native_path(param);
			return(true);
		}
		return(base.on_command_line_parameter(param));
	}

	public bool execute() {
		if(source == null || dest == null || String.is_empty(type)) {
			usage();
			return(false);
		}
		Log.message("Compiling manual: `%s' -> `%s'".printf().add(source).add(dest));
		bool r;
		if("html".equals(type)) {
			r = ManualToHTMLCompiler.compile(source, dest);
		}
		else if("db".equals(type)) {
			r = ManualToDatabaseCompiler.compile(source, dest);
		}
		else {
			Log.error("Unknown compilation type: `%s'".printf().add(type));
			r = false;
		}
		if(r == false) {
			Log.error("FAILED to compile to: `%s'".printf().add(dest));
			return(1);
		}
		Log.message("OK: `%s'".printf().add(dest));
		return(0);
	}
}
