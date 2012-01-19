#!/usr/bin/perl

use strict;
use warnings;

use HTML::WordCloud;
use File::Slurp;
use Data::Dumper;

my $moby = read_file('./script/moby_dick.txt');

#my @words = qw/this is a bunch of words/;
my @words = split /\s+/, $moby;

#my %wordhash = map { shift @words => $_ } (1 .. ($#words+1));

my $wc = new HTML::WordCloud(prune_boring => 1, word_count => 70);

$wc->words(\@words);

#print Dumper($wc->words);

binmode STDOUT;

for (1 .. 12) {
	my $img = $wc->cloud();

	write_file('/www/vhosts/c0bra.net/htdocs/wordcloud/moby' . $_ . '.png', {binmode => ':raw'}, $img->png);
}