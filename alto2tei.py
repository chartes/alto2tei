#! /usr/bin/python3
# -*- coding: utf-8 -*-


# standard library imports
import base64
import logging
import pathlib
import zipfile
import argparse
import configparser

from io import BytesIO

# third party imports
import urllib3
import regex as re

from lxml import etree

# library specific imports


__version__ = "0.1.0"


PRE_REGEXES = (
    (   # titre courant page paire
        r"(<page.*>)\n<p[^>]*>\n(?:<tt>)?([0-9]+).*\n</p>",
        r"\g<1>\n<fw>\g<2></fw>"
    ),
    (   # titre courant page impaire
        r"(<page.*>)\n<p[^>]*>\n[^0-9]+([0-9]+)(?:</tt>)?\n</p>",
        r"\g<1>\n<fw>\g<2></fw>"
    ),
    (   # n° de feuillet
        r"[iI]+\. *[0-9]+(\s*</p>\s*</page>)",
        r"\g<1>"
    ),
    (   # marquer les guillemets ouvrants en début de ligne précédés
        # d’un guillemet ouvrant, avec assertions pour tromper le
        # pointeur
        r"(?<=«)([^»\n]*\n(<[^>]+>)?)(?=«)",
        r"\g<1>µµµ"
    ),
    (   # supprimer les guillemets marqués ci-dessus
        r"µµµ«",
        r""
    ),
    (
        r"(<small>) +",
        r"\g<1>"
    ),
    (   # espace laissé par les césures résolues
        r"(\n) +",
        r"\g<1>"
    ),
    (   # césure, raccrocher balises de lignes
        r"-</small>\n<small>([^ ]*)",
        r"\g<1>\n"
    ),
    (
        # raccrocher balises de lignes
        r"</small>\n<small>",
        r"\n"
    ),
    (
        r"</(b|i|u|sc|sub)>(\s*)<\1>",
        r"\g<2>"
    ),
    (
        r"\.\.\.",
        r"…"
    ),
    (
        r"([cCdDjJlLmMnNsStT]|qu|Qu)\'",
        r"\g<1>’"
    ),
    (
        # rendre insécable les espaces existants
        r"([«]) ",
        r"\g<1>"
    ),
    (
        # espace insécable après guillemets
        r"([«])([^ ])",
        r"\g<1> \g<2>"
    ),
    (
        # rendre insécable les espaces avant ponctuation double
        r" ([;:!?»])",
        r" \g<1>"
    ),
    (
        r"\)([^. ])",
        r") \g<1>"
    ),
    (   # Attention à ':' dans les URI et ';' dans les entités
        r"([^ ])([;!?»])",
        r"\g<1> \g<2>"
    ),
    (
        # protect entities
        r"(&#?[a-zA-Z0-9]+) ;",
        r"\g<1>;"
    ),
    (
        # certaines ponctuations hors ital
        r"( [;\?!])</(i|sup)>",
        r"</\g<2>>\g<1>"
    ),
    (
        # certaines ponctuations hors ital
        r"([,.])</(i|sup)>",
        r"</\g<2>>\g<1>"
    ),
    (
        r"<sup>Mme</sup>",
        r"M<sup>me</sup>"
    ),
    (
        r"ae",
        r"æ"
    ),
    (
        r"oe",
        r"œ"
    ),
    (
        r"A[Ee]",
        r"Æ"
    ),
    (
        r"O[Ee]",
        r"Œ"
    ),
    (
        # n° de note à libérer
        r"<small>\s*<i>([0-9]+\.?)</i>",
        r"<small>\g<1>"
    ),
    (
        r"<sup>in-([0-9]+)°</sup>",
        r"in-\g<1>°"
    ),
    (
        r"<sup>([0-9IVXVLCMxvi]+)(er?|[èe]re)</sup>",
        r"<num>\g<1><sup>\g<2></sup></num>"
    ),
    (
        # sortir parenthèse ouvrante
        r"<i>([\(])",
        r"\g<1><i>"
    ),
    (
        # titres de section ?
        r"<p[^>]*>\s*<big>(.*)</big>\s*</p>",
        r"<h1>\g<1></h1>"
    ),
    (
        # titre de section en chiffres romains
        r"<p[^>]*>\n([IVXLC]+\.?)\n</p>",
        r"<h2>\g<1></h2>"
    ),
    (
        # titres de page en capitales
        r"<p[^>]*>\n([0-9A-ZÉÈÀÇŒÆ\'’]+)\n</p>",
        r"<h1>\g<1></h1>"
    ),
    (
        r"</h([1-6])>\s*<h(\1)>",
        r" "
    ),
    (
        r"<h([1-6])>",
        r'<head n="\g<1>">'
    ),
    (
        r"</h([1-6])>",
        r"</head>"
    ),
)


POST_REGEXES = (
    (
        # écrire les <div>
        r"<\?div\?>",
        r"<div>"
    ),
    (
        # écrire les </div>
        r"<\?div /\?>",
        r"</div>"
    ),
    (
        # raccrocher les paragraphes autour des sauts de page
        r"</p>\s*(<pb[^>]*/>)\s*<p[^>]*>\s*(\p{Ll})",
        r"\n\g<1>\g<2>"
    ),
    (
        # retirer les n° des notes reconnues7
        r'(<note xml:id="[^"]+">)\s*[0-9]+\.\s+',
        r"\g<1>\n"
    ),
    (
        # coller l’appel de note
        r" +(<note)",
        r"\g<1>"
    ),
    (
        r"|".join(("\r", "\n", "\r\n")),
        r""
    ),
)


class Transformer():
    """ALTO to TEI transformer."""

    ALTO_NS = "http://www.loc.gov/standards/alto/ns-v4#"

    def __init__(self, args, config, pre_regexes, post_regexes):
        """Initialise transformer.

        :param Namespace args: command-line arguments
        :param ConfigParser config: config
        :param tuple pre_regexes: pre-TEI transformation regexes
        :param tuple post_regexes: post-TEI transformation regexes
        """
        self.logger = logging.getLogger(self.__class__.__name__)
        self.args = args
        self.config = config
        self.pre_regexes = pre_regexes
        self.post_regexes = post_regexes

    def _update_text_lines(self, file_name, lines, text_lines):
        """Update TextLine list.

        :param str file_name: XML file
        :param str lines: XML file content
        :param list text_lines: TextLine list
        """
        tree = etree.parse(
            BytesIO(lines),
            etree.XMLParser(remove_blank_text=True)
        )
        namespaces = {
            k if k else "default": i
            for k, i in tree.getroot().nsmap.items()
        }
        information = tree.xpath(
            "//default:alto/default:Description/default:sourceImageInformation",    # noqa
            namespaces=namespaces
        )
        for name in ("fileIdentifier", "fileName"):
            try:
                url = information[0].xpath(
                    f"./default:{name}/text()",
                    namespaces=namespaces
                )
            except IndexError:
                continue
            if url:
                break
        else:
            self.logger.warning(
                f"skipping {file_name} TextLine list (no 'fileIdentifier' or 'fileName')"    # noqa
            )
            return
        text_lines += [
            [
                item[0] if item else ""
                for item in [
                    node.xpath(".//@ID"),
                    url,
                    node.xpath(".//@HPOS"),
                    node.xpath(".//@VPOS"),
                    node.xpath(".//@WIDTH"),
                    node.xpath(".//@HEIGHT"),
                    node.xpath(
                        "./default:Shape/default:Polygon/@POINTS",
                        namespaces=namespaces
                    )
                ]
            ]
            for node in tree.xpath("//default:TextLine", namespaces=namespaces)
        ]

    def _transform_xslt(self, content, xslt, replace_ns=False, **kwargs):
        """Transform content using XSLT.

        :param str content: XML file content
        :param str xslt: XSLT file name

        :returns: transformed content
        :rtype: str
        """
        parser = etree.XMLParser(remove_blank_text=True)
        try:
            tree = etree.parse(BytesIO(content), parser)
            if replace_ns:
                nsmap = tree.getroot().nsmap
                if None in nsmap.keys() and nsmap[None] != self.ALTO_NS:
                    old_ns = nsmap[None]
                    self.logger.warning(
                        f"replace deprecated namespace '{old_ns}' "
                        f"by '{self.ALTO_NS}'"
                    )
                    with open(self.config["xsl"]["ns"]) as fp:
                        tree = etree.XSLT(etree.parse(fp, parser))(
                            tree,
                            old_ns=f"'{old_ns}'",
                            new_ns=f"'{self.ALTO_NS}'"
                        )
            with open(xslt, "rb") as fp:
                transformer = etree.XSLT(etree.parse(fp, parser))
                return str(
                    transformer(
                        tree,
                        **kwargs
                    ),
                    encoding="utf-8",
                )
        except Exception as exception:
            logging.getLogger(self.__class__.__name__).exception(exception)
            raise SystemExit

    def _transform_regexes(self, content, regexes=tuple()):
        """Transform content using regexes.

        :param str content: XML file content
        :param tuple regexes: regexes

        :returns: transformed content
        :rtype: str
        """
        for regex, repl in regexes:
            try:
                content = re.sub(regex, repl, content)
            except Exception as exception:
                logging.getLogger(self.__class__.__name__).exception(exception)
                raise SystemExit
        return content

    def _format_iiif_url(self, url, hpos, vpos, width, height):
        """Format IIIF URL.

        :param str url: URL
        :param str hpos: upper left x position
        :param str vpos: upper left y position
        :param str width: width
        :param str height: height

        :returns: formatted IIIF URL
        :rtype: str
        """
        # {scheme}://{server}{/prefix}/{identifier}/{region}/{size}/{rotation}/{quality}.{format}
        url = urllib3.util.parse_url(url)
        path = url.path.split("/")
        return str(
            urllib3.util.url.Url(
                scheme=url.scheme,
                auth=url.auth,
                host=url.host,
                port=url.port,
                path="/".join(
                    (
                        *path[:-4],     # replace 'full' by pixel coordinates
                        ",".join((hpos, vpos, width, height)),
                        *path[-3:]
                    )
                ),
                query=url.query,
                fragment=url.fragment,

            )
        )

    def _get_facsimile(self, text_lines):
        """Get facsimile element.

        :param list text_lines: list of TextLines

        :returns: facsimile element
        :rtype: str
        """
        surfaces = []
        for text_line in text_lines:
            id_, url, hpos, vpos, width, height, points = text_line
            if "iiif" in url:
                url = self._format_iiif_url(url, hpos, vpos, width, height)
            ulx = f' ulx="{hpos}"' if hpos else ""
            uly = f' uly="{vpos}"' if vpos else ""
            lrx = f' lrx="{width}"' if width else ""
            lry = f' lry="{height}"' if height else ""
            points = points.split()
            points = " ".join(
                f"{points[i-1]},{points[i]}"
                for i in range(1, len(points))[::2]
            )
            points = f' points="{points}"' if points else ""
            surfaces.append(
                (
                    "<surface>"
                    f'<graphic url="{url}"/>'
                    f'<zone xml:id="{id_}"{ulx}{uly}{lrx}{lry}{points}/>'
                    "</surface>"
                )
            )
        text_lines.clear()  # free memory
        return f"<facsimile>{''.join(surface for surface in surfaces)}</facsimile>" # noqa

    def transform(self):
        """Transform ALTO file(s) to TEI."""
        filenames = sorted(
            self.args.input_dir.iterdir(),
            key=lambda x: str(x)
        )
        if not filenames:
            self.logger.info("No ALTO files")
            return
        i = 1
        self.logger.debug(
            f"step {i}: read in {len(filenames)} ALTO "
            f"file{'s' if len(filenames) > 1 else ''}"
        )
        content = ""
        text_lines = []
        for filename in filenames:
            if filename.suffix not in (".xml", ".XML"):
                continue
            self.logger.debug(f"read in {filename}")
            with filename.open("rb") as fp:
                lines = fp.read()
            self._update_text_lines(filename.name, lines, text_lines)
            content += self._transform_xslt(
                lines,
                self.config["xsl"]["work"],
                replace_ns=True,
                page_id=f"'{base64.b64encode(filename.name.encode()).decode()}'",   # noqa
                no_facsimile=str(int(self.args.no_facsimile)),
            )
        i += 1
        self.logger.debug(f"step {i}: apply pre-TEI transformation regexes")
        content = self._transform_regexes(content, self.pre_regexes)
        content = "".join(
            (
                '<?xml version="1.0" encoding="UTF-8"?>',
                "<!-- appel des schémas/transformations -->",
                '<TEI xmlns="http://www.tei-c.org/ns/1.0" xml:lang="fr">',
                "<teiHeader>",
                "<fileDesc>",
                "<titleStmt>",
                f"<title>Conversion alto2tei de {self.args.input_dir.name}</title>",    # noqa
                "</titleStmt>",
                "<publicationStmt>",
                "<publisher></publisher>",
                "</publicationStmt>",
                "<sourceDesc>",
                f"<p>{self.args.input_dir.name}</p>",
                "</sourceDesc>",
                "</fileDesc>",
                "</teiHeader>",
                self._get_facsimile(text_lines) if self.args.no_facsimile else "",   # noqa
                "<text>",
                "<body>",
                content,
                "</body>",
                "</text>",
                "</TEI>"
            )
        )
        i += 1
        self.logger.debug(f"step {i}: apply TEI transformation")
        content = self._transform_xslt(
            content.encode("utf-8"),
            self.config["xsl"]["tei"]
        )
        i += 1
        self.logger.debug(f"step {i}: apply post-TEI transformation regexes")
        content = self._transform_regexes(
            content,
            self.post_regexes
        )
        self.logger.debug(f"write output file {self.args.output_filename}")
        with open(self.args.output_filename, "wb") as fp:
            fp.write(
                etree.tostring(
                    etree.parse(
                        BytesIO(content.encode("utf-8")),
                        etree.XMLParser(remove_blank_text=True)
                    ),
                    pretty_print=True,
                    encoding="utf-8"
                )
            )


def _init_config():
    """Initalize config.

    :returns: config
    :rtype: ConfigParser
    """
    parent = pathlib.Path(__file__).parent.resolve()
    xsl = parent / "xsl"
    config = configparser.ConfigParser()
    config.read_dict(
        {
            "xsl": {
                "work": str(xsl / "alto2work.xsl"),
                "tei": str(xsl / "work2tei.xsl"),
                "ns": str(xsl / "replacens.xsl"),
            }
        }
    )
    return config


def _input_dir(dir_):
    """Cast directory to Path object.

    :param str dir_: directory

    :raises FileNotFoundError: if directory does not exist

    :returns: directory
    :rtype: Path
    """
    if zipfile.is_zipfile(dir_):
        return zipfile.Path(dir_)
    dir_ = pathlib.Path(dir_)
    if not dir_.is_dir():
        raise FileNotFoundError(f"No such directory: {dir_}")
    return dir_


def _init_argument_parser():
    """Initialize ArgumentParser object.

    :returns: intialized ArgumentParser object
    :rtype: ArgumentParser
    """
    parser = argparse.ArgumentParser(
        prog="alto2tei",
        description="Lorem ipsum",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "input_dir",
        type=_input_dir,
        help="input directory",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
        help="print %(prog)s version",
    )
    parser.add_argument(
        "--level",
        default="INFO",
        choices=("INFO", "DEBUG"),
        help="set logging level",
    )
    parser.add_argument(
        "-o",
        "--output-filename",
        default="<input directory>.xml",
        help="output filename",
    )
    parser.add_argument(
        "--no-facsimile",
        action="store_false",
        help="do not include facsimiles"
    )
    return parser


def main():
    """Main routine."""
    parser = _init_argument_parser()
    args = parser.parse_args()
    if args.output_filename == parser.get_default("output_filename"):
        args.output_filename = f"{args.input_dir.stem}.xml"
    logging.basicConfig(
        format="[%(asctime)s] %(levelname)s %(name)s: %(message)s",
        level=logging.getLevelName(args.level),
    )
    logger = logging.getLogger(main.__name__)
    logger.info(f"transform {args.input_dir} into {args.output_filename}")
    transformer = Transformer(args, _init_config(), PRE_REGEXES, POST_REGEXES)
    transformer.transform()


if __name__ == "__main__":
    main()
