#!/usr/bin/perl

use strict;
use warnings;

use 5.010_001; # Need Perl version 5.10 for Coalesce operator (//)
use Mac::iTunes::Library;
use Mac::iTunes::Library::XML;

# How far to indent the 'current' line of output
# Do a ++ before the start of each loop
# Do a -- as soon as the loop is complete
my $indent = 0;
my $indent_multiplier = 3;

my $fname = 'itunes.xml';
&feedback(sprintf('Reading libary file [%s]', $fname));
&feedback('This could take a while because Apple does not understand XML');
&feedback('Please be patient, they a little stupid...');
my $library = Mac::iTunes::Library::XML->parse( 'itunes.xml');

printf("\nParsed library version %u.%u from iTunes %s with %u items\n",
	$library->majorVersion(), $library->minorVersion(), $library->applicationVersion(), $library->num());

my $fmt="%-20s: %s";

&feedback(sprintf($fmt, 'Features', 		$library->features()));
&feedback(sprintf($fmt, 'Content Ratings',	$library->showContentRatings()));
&feedback(sprintf($fmt, 'Music Folder',		$library->musicFolder()));
&feedback(sprintf($fmt, 'Persistent ID',	$library->libraryPersistentID()));
&feedback(sprintf($fmt, 'Total Size',		$library->size()));
&feedback(sprintf($fmt, 'Total Time',		$library->time()));

my %playlists = $library->playlists();
my $audio_files	= 0;
my $purchased	= 0;
$indent++;
while (my ($id, $playlist) = each %playlists) {
	# Built-in playlists needs to be skipped
	next if ($playlist->name eq 'Music');
	next if ($playlist->name eq 'Library');

	&feedback(sprintf($fmt, 'Playlist Name',	$playlist->name));
	&feedback(sprintf($fmt, 'Playlist ID',		$playlist->playlistID));
	&feedback(sprintf($fmt, 'Item Count',		$playlist->num));

	my @pl_items = $playlist->items();
	$indent++;
	foreach my $song (@pl_items) {
		# Each item (song) in the playlist
		my $artist	= $song->artist	// $song->albumArtist	// '';
		my $title	= $song->name	// '';
		my $media	= $song->kind	// 'UNKNOWN';

		# We don't want to include video files
		next if ($media =~ m/\bvideo\b/i);
		next if ($media =~ m/\bmovie\b/i);

		# Counters
		$audio_files++;
		$purchased++ if ($media =~ m/\bpurchased\b/i);

		&feedback($media);
		&feedback(sprintf('%s - %s', $artist, $title));
	}
	$indent--;
}
$indent--;

&feedback('Total number of items in playlists: '.$audio_files);
&feedback('Total number of purchased items: '.$purchased);

exit 0;

###############################################################################

sub feedback() {
	my ($msg) =  @_;
	my $num_of_spaces = ($indent*$indent_multiplier);
	print(' 'x$num_of_spaces);
	print("$msg\n");
	return 1;
}
