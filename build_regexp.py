#! /usr/bin/env python3.6
import re
import urllib.request
import sys
import telnetlib
import os
import argparse
import logging
from typing import Tuple, List
import idna

def get_non_ascii(prod: bool, python: bool):
    cachefile = os.path.abspath("navnepolitikk.txt")
    if prod:
        resource = urllib.request.urlopen(
            "https://www.norid.no/en/regelverk/navnepolitikk/")
        s = resource.read().decode(resource.headers.get_content_charset())
        if not os.path.isfile(cachefile):
            try:
                with open(cachefile, 'w', encoding="utf-8") as f:
                    f.write(s)
            except OSError as ose:
                logging.warning("Failed to write cachefile ({}): {}".format(cachefile, ose))
    else:
        old_cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        if os.path.isfile(cachefile):
            a_file = open(cachefile, encoding='utf-8')
            s = a_file.read()
        else:
            logging.error("Could not find {} in script dir. Run one with --prod to cache data.".format(cachefile))
            sys.exit(1)
        os.chdir(old_cwd)

    result = re.search('<a id="link3">(.*)<a id="link4">', s,
                       re.MULTILINE | re.DOTALL)
    chars = []
    for c in result.group(0):
        if ord(c) > 0xBF:  # because 'NO-BREAK SPACE' (U+00A0)
            chars.append(c)

    chars = sorted(set(chars))
    r = []
    for c in chars:
        if python:
            r.append((c, c.encode('unicode_escape').decode('utf-8')))
        else:
            r.append((c, "\\x{" + "{:0X}".format(ord(c)) + "}"))
    # list of pairs oc unicode char and \x-escape
    return r


def get_cat_domains(repl: List[Tuple[str, str]], prod: bool, tld: bool):
    cachefile = "whois.txt"
    if prod:
        whois = telnetlib.Telnet("whois.norid.no", 43)
        whois.write("-c utf-8 NNRI4O-NORID\n".encode('ascii'))
        result = whois.read_all()
        whois.close()
        s = result.decode('utf-8')
        if not os.path.isfile(cachefile):
            try:
                with open(cachefile, 'w', encoding="utf-8") as f:
                    f.write(s)
            except OSError as ose:
                logging.warning("Failed to write cachefile ({}): {}".format(cachefile, ose))
    else:
        old_cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        if os.path.isfile(cachefile):
            a_file = open('whois.txt', encoding='utf-8')
            s = a_file.read()
        else:
            logging.error("Could not find {} in script dir. Run one with --prod to cache data.".format(cachefile))
            sys.exit(1)
        os.chdir(old_cwd)

    r = re.search('^Domains\.*: (.*)', s, re.MULTILINE)
    pairs = []
    if r:
        domains = r.group(1).split()
        for i in enumerate(domains):
            if domains[i[0]] == 'no.':
                # One of the domains are "no."
                continue
            if not tld:
                # Drop TLD (.no), 3 chars
                domains[i[0]] = domains[i[0]][:-3]
            pre = domains[i[0]]
            idn = idna.encode(pre).decode("utf-8")
            if idn != pre:
                pairs.append((pre, idn))
            for (q, t) in repl:
                domains[i[0]] = domains[i[0]].replace(q, t)

            pairs.append((pre, domains[i[0]]))
    else:
        logging.error("Failed to find regexp math in data.")
        sys.exit(1)

    return pairs


def build_regexp(prod: bool, python: bool):
    valid_chars_ex_dash = "[a-z0-9"
    chars = get_non_ascii(prod, python)
    for char in chars:
        valid_chars_ex_dash += char[1]
    valid_chars_ex_dash += "]"
    logging.debug("valid_chars_ex_dash: {}".format(valid_chars_ex_dash))

    domains = get_cat_domains(repl=chars, prod=prod, tld=False)
    valid_cat_domains = "(?:"
    valid_cat_domains += "|".join([d[1] for d in domains])
    valid_cat_domains += ")"
    logging.debug("valid_cat_domains: {}".format(valid_cat_domains))

    regexp = "((?:{0}(?:{0}|-){{0,61}}{0}|(?:{0}|{0}(?:{0}|-){{0,61}}{0})\.{1})\.no)(?!{0})"
    #regexp = "((?:{0}(?:{0}-){{0,61}}{0}|(?:{0}|{0}(?:{0}-){{0,61}}{0})\.{1})\.no)(?!{0})"
    logging.debug('"{}".format(valid_chars_ex_dash, valid_cat_domains)'.format(regexp))
    print(regexp.format(valid_chars_ex_dash, valid_cat_domains))


def main():
    parser = argparse.ArgumentParser(
        description=
        'Utility to print the chars and category domains allowed '
        'in a .no domain. Data can be from cache (default) or live data.'
    )
    parser.add_argument("-p", "--prod", help='Uses live data', action="store_true", default=False)
    parser.add_argument("-u", "--unescaped", help='Print only unescaped values (default both)',
                        action="store_true", default=False)
    parser.add_argument("-e", "--escaped", help='Print escaped values (default both)',
                        action="store_true", default=False)
    parser.add_argument("-c", "--chars", help='Print the valid non-ascii chars', action="store_true", default=False)
    parser.add_argument("-d", "--domains", help='Print the valid category domains', action="store_true", default=False)
    parser.add_argument("-b", "--build", help='Build regexp for .no domains', action="store_true", default=False)
    parser.add_argument("-t", "--tld", help='Include TLD(.no) when printing domains',
                        action="store_true", default=False)
    parser.add_argument("-y", "--python", help='Escape for Python (\\u<CODEPOINT) instead of Perl (\\x<CODEPOINT)',
                        action="store_true", default=False)
    parser.add_argument("-g", "--debug", help='Set loglevel DEBUG', action="store_true", default=False)
    args = parser.parse_args()

    if args.debug:
        logger = logging.getLogger()
        logger.setLevel(logging.DEBUG)

    if args.chars or args.domains:
        pairs = get_non_ascii(args.prod, args.python)
        if args.chars:
            for pair in pairs:
                if not (args.unescaped or args.escaped):
                    print("{}\t{}".format(pair[0], pair[1]))
                elif args.unescaped:
                    print(pair[0])
                else:
                    print(pair[1])
        if args.domains:
            for domain in get_cat_domains(pairs, args.prod, args.tld):
                if not (args.unescaped or args.escaped):
                    print("{}\t{}".format(domain[0], domain[1]))
                elif args.unescaped:
                    print(domain[0])
                else:
                    print(domain[1])
    if args.build:
        build_regexp(args.prod, args.python)


if __name__ == '__main__':
    main()
