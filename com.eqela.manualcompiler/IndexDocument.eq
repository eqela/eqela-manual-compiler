
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

class IndexDocument
{
	public static IndexDocument for_file(File file) {
		return(new IndexDocument().parse(file));
	}

	property String title;
	property String description;
	property Collection references;

	public IndexDocument parse(File file) {
		if(file == null) {
			return(null);
		}
		foreach(String line in file.lines()) {
			line = line.strip();
			if(String.is_empty(line) || line.has_prefix("#")) {
				continue;
			}
			var sp = StringSplitter.split(line, ':', 2);
			var key = sp.next() as String;
			var val = sp.next() as String;
			if(key != null) {
				key = key.strip();
			}
			if(val != null) {
				val = val.strip();
			}
			if("title".equals(key)) {
				title = val;
			}
			else if("description".equals(key)) {
				description = val;
			}
			else if("reference".equals(key)) {
				if(val != null) {
					if(references == null) {
						references = LinkedList.create();
					}
					references.append(val);
				}
			}
		}
		return(this);
	}
}
