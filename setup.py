# -*- coding: utf-8 -*-


# standard library imports
# third party imports
import setuptools
# library specific imports


setuptools.setup(
    name="alto2tei",
    install_requires=["lxml", "regex", "urllib3"],
    entry_points={"console_scripts": ["alto2tei = alto2tei:main"]},
)
