#!/usr/bin/env python3
"""Generate the three empty OOXML templates (feedback H3).

They are ZIP containers, so keeping them in git would mean binaries that
diff badly; the package builds them instead. Each file is the smallest
document the format allows: the content-type map, the package
relationship and one empty body part. Nothing on the ISO opens them yet
(an office suite comes from the store, group G), but the "New file" menu
must offer them and a real office app must accept the result.
"""
import sys
import zipfile

CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/{part}" ContentType="{ctype}"/>
</Types>
"""

RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="{rtype}" Target="{part}"/>
</Relationships>
"""

DOCX_BODY = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body><w:p/></w:body>
</w:document>
"""

XLSX_BOOK = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>
"""

XLSX_SHEET = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetData/>
</worksheet>
"""

PPTX_PRES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:sldMasterIdLst/><p:sldIdLst/>
<p:sldSz cx="12192000" cy="6858000"/><p:notesSz cx="6858000" cy="9144000"/>
</p:presentation>
"""

OFFICE = ("http://schemas.openxmlformats.org/officeDocument/2006"
          "/relationships/officeDocument")
WORKSHEET = ("http://schemas.openxmlformats.org/officeDocument/2006"
             "/relationships/worksheet")


def write(path, parts):
    """Write one OOXML package; parts maps archive names to text."""
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as archive:
        for name, text in parts.items():
            archive.writestr(name, text)


def main(outdir):
    """Write Document.docx, Spreadsheet.xlsx and Presentation.pptx."""
    write(outdir + "/Document.docx", {
        "[Content_Types].xml": CONTENT_TYPES.format(
            part="word/document.xml",
            ctype="application/vnd.openxmlformats-officedocument"
                  ".wordprocessingml.document.main+xml"),
        "_rels/.rels": RELS.format(rtype=OFFICE, part="word/document.xml"),
        "word/document.xml": DOCX_BODY,
    })

    xlsx_types = CONTENT_TYPES.format(
        part="xl/workbook.xml",
        ctype="application/vnd.openxmlformats-officedocument"
              ".spreadsheetml.sheet.main+xml").replace(
        "</Types>",
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType='
        '"application/vnd.openxmlformats-officedocument'
        '.spreadsheetml.worksheet+xml"/>\n</Types>')
    write(outdir + "/Spreadsheet.xlsx", {
        "[Content_Types].xml": xlsx_types,
        "_rels/.rels": RELS.format(rtype=OFFICE, part="xl/workbook.xml"),
        "xl/workbook.xml": XLSX_BOOK,
        "xl/_rels/workbook.xml.rels": RELS.format(
            rtype=WORKSHEET, part="worksheets/sheet1.xml"),
        "xl/worksheets/sheet1.xml": XLSX_SHEET,
    })

    write(outdir + "/Presentation.pptx", {
        "[Content_Types].xml": CONTENT_TYPES.format(
            part="ppt/presentation.xml",
            ctype="application/vnd.openxmlformats-officedocument"
                  ".presentationml.presentation.main+xml"),
        "_rels/.rels": RELS.format(rtype=OFFICE,
                                   part="ppt/presentation.xml"),
        "ppt/presentation.xml": PPTX_PRES,
    })


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
