#!/usr/local/bin/perl

use strict;

my @sources = ();

while (<STDIN>) {
    # skip some junk
    next if m/^ghc.*:/o;
    # select the right lines
    if(m#^(Skip|Com).*\( ([\w.\-/]+\.l?hs),#o) {
	push @sources, $2;
	
    }
}

print 
'# This file is generated by create_sources.pl
# Please do not edit 
sources = ', join(' ', @sources), "\n";
