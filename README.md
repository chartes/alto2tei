# alto2tei

Command line program to convert [ALTO](https://www.loc.gov/standards/alto/) files to [XML/TEI](https://tei-c.org/).

## Credits

Alto2tei is a python3 migration of the PHP tool developed at Labex Obvil (Sorbonne University) for the TGB project, maintained by F. Glorieux (saxalto).


## Features

Alto2tei introduces several new features, including:

- support for deprecated ALTO namespaces.
- support for `alto:fileIdentifier` and `alto:Page/@PHYSICAL_IMG_NR`.
- creation of `tei:facsimile` and support for optional linking to image area identifiers.
- Support for `@TAGREFS` for the management of semantic zone types.
- Support for the SegmOnto controlled vocabulary.

The aim of this ongoing project is to maintain the typographic support of the previous application and add a semantic support, to efficiently transform eScriptorium exports.


## Install

Start by cloning the repository, and moving inside the created folder

```
https://github.com/chartes/alto2tei.git
cd alto2tei
```

Create a virtual environment, source it

```
python3.8 -m venv venv
source venv/bin/activate
```

Run

```
pip install -e .
```


## Usage

```
alto2tei --help 

usage: alto2tei [-h] [--version] [--level {INFO,DEBUG}] [-o OUTPUT_FILENAME] [--no-facsimile]
                input_dir

positional arguments:
  input_dir             input directory

optional arguments:
  -h, --help            show this help message and exit
  --version             print alto2tei version
  --level {INFO,DEBUG}  set logging level (default: INFO)
  -o OUTPUT_FILENAME, --output-filename OUTPUT_FILENAME
                        output filename (default: <input directory>.xml)
  --no-facsimile        do not include facsimiles (default: True)
```

## TODO

- continue SegmOnto implementation 
- evaluate for SegmOnto the relevance of text standardisations (e.g. case, apostrophes, spaces).
- substitute `tei:sourceDoc` for `tei:facsimile`.


## Contributors

C. Dengler, V. Jolivet