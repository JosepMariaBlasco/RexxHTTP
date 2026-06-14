Parse Arg version .
date = date(s)

zip1     = "rexxhttp-"version"-"date".zip"
zip2     = "rexxhttp-latest.zip"
"del"    zip1
"del"    zip2
"zip -r" zip1 "* -x pack.rex *trace.xml *.zip *.deb *.war *.gz"
"zip -r" zip2 "* -x pack.rex *trace.xml *.zip *.deb *.war *.gz"
