#! /usr/bin/env python3
import re
import urllib.request
import sys
import telnetlib
import os
import argparse
import logging


def get_non_ascii(prod):
    if len(sys.argv) > 1 and sys.argv[1] == "--prod":
        resource = urllib.request.urlopen(
            "https://www.norid.no/en/regelverk/navnepolitikk/")
        s = resource.read().decode(resource.headers.get_content_charset())
    else:
        old_cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        a_file = open('navnepolitikk.txt', encoding='utf-8')
        s = a_file.read()
        os.chdir(old_cwd)

    result = re.search('<a id="link3">(.*)<a id="link4">', s,
                       re.MULTILINE | re.DOTALL)
    chars = []
    for c in result.group(0):
        if (ord(c) > 0xBF):  # because 'NO-BREAK SPACE' (U+00A0)
            chars.append(c)

    chars = sorted(set(chars))
    r = []
    for c in chars:
        r.append((c, "\\x{" + "{:0X}".format(ord(c)) + "}"))
    # list of pairs oc unicode char and \x-escape
    return r


def get_cat_domains(repl, prod):
    if prod:
        whois = telnetlib.Telnet("whois.norid.no", 43)
        whois.write("-c utf-8 NNRI4O-NORID\n".encode('ascii'))
        result = whois.read_all()
        whois.close()
        s = result.decode('utf-8')
    else:
        old_cwd = os.getcwd()
        os.chdir(os.path.dirname(os.path.realpath(__file__)))
        a_file = open('whois.txt', encoding='utf-8')
        s = a_file.read()
        os.chdir(old_cwd)

    r = re.search('^Domains\.*: (.*)', s, re.MULTILINE)
    if r:
        domains = r.group(1).split()
        repl = get_non_ascii()
        for i in enumerate(domains):
            for (q, t) in repl:
                domains[i[0]] = domains[i[0]].replace(q, t)
        return domains


def main():
    parser = argparse.ArgumentParser(
        description=
        'Utility to print the chars and category domains allowed '
        'in a .no domain. Data can be from cache (default) or live data.'
    )
    parser.add_argument(
                      "-p",
                      "--prod",
                      help='Uses live data',
                      action="store_true")
  args = parser.parse_args()    
production = False
    pairs = get_non_ascii()
    for pair in pairs:
        print(pair[0], pair[1])
    print(get_cat_domains(na))


if __name__ == '__main__':
    main()
