#!/usr/bin/perl

use strict;
use warnings;

use 5.010_001; # Need Perl version 5.10 for Coalesce operator (//)
use Mac::iTunes::Library;
use Mac::iTunes::Library::XML;
use URI::Escape;
use Number::Bytes::Human qw(format_bytes);

# how far to indent the 'current' line of output
# Do a ++ before the start of each loop
# Do a -- as soon as the loop is complete
my $indent = 0;
my $INDENT_MULTIPLIER = 3;

# Format for column printing feedback
my $FMT="%-15s: %s";

# what database file are we meant to process?
my $fname = 'itunes.xml';
&bomb('File not found: '.$fname) unless (-e $fname);

&feedback(sprintf('Reading libary file [%s]', $fname));
&feedback('This could take a while because Apple does not understand XML');
&feedback('Please be patient, they fucked this up...');
my $library = Mac::iTunes::Library::XML->parse($fname);

print;
&feedback(sprintf('Read library ID [%s] (Version %u.%u from iTunes %s)',
		$library->libraryPersistentID,
		$library->majorVersion,
		$library->minorVersion,
		$library->applicationVersion,
	));

&feedback(sprintf($FMT, 'Number of Items',	$library->num));
&feedback(sprintf($FMT, 'Music Folder',		$library->musicFolder));
&feedback(sprintf($FMT, 'Persistent ID',	$library->libraryPersistentID));
&feedback(sprintf($FMT, 'Total Size',		format_bytes($library->size)));

# we need this to search and replace it in the song path
my $library_path = $library->musicFolder;

# Loop through each playlist in the library
my $audio_files	= 0;
my $purchased	= 0;
my %playlists = $library->playlists();
print;
&feedback(sprintf('Found %u playlists to process', keys(%playlists)));
$indent++;
while (my ($id, $playlist) = each %playlists) {
	# Built-in playlists needs to be skipped
	next if ($playlist->name eq 'Music');
	next if ($playlist->name eq 'Library');
	next if ($playlist->name eq 'TV Shows');
	next if ($playlist->name eq 'Movies');

	# open our output file
	my $oname = sprintf('/tmp/playlists/%s.m3u', $playlist->name);
	open (PLFILE, ">$oname");

	&feedback(sprintf($FMT, 'Playlist Name',	$playlist->name));
	&feedback(sprintf($FMT, 'Playlist ID',		$playlist->playlistID));
	&feedback(sprintf($FMT, 'Item Count',		$playlist->num));
	&feedback('Output file is: '.$oname);

	my @pl_items = $playlist->items();
	$indent++;
	foreach my $song (@pl_items) {
		# We don't want to include video files
		next if ($song->kind =~ m/\bvideo\b/i);
		next if ($song->kind =~ m/\bmovie\b/i);

		my $artist		= $song->artist	// $song->albumArtist	// '';
		my $title		= $song->name	// '';
		my $song_path	= uri_unescape($song->location);
		# remove the library path from the front of the song location so we
		# have a relative path to the file since we are unlikely to have the
		# same paths on systems other than the itunes computer.
		# note that \Q and \E delimit where NOT to interpret regex patterns
		# so slashes etc in the variable don't confuse the regex engine and
		# give false (not) matches.
		$song_path =~ s|^\Q$library_path\E||;

		# Counters
		$audio_files++;
		$purchased++ if ($song->kind =~ m/\bpurchased\b/i);

		&feedback(sprintf('%s - %s', $artist, $title));
		&feedback('  ===> '.$song_path);
		print PLFILE "$song_path\n";
	}
	$indent--;
	close (PLFILE); 
}
$indent--;

&feedback('Total number of items in playlists: '.$audio_files);
&feedback('Total number of purchased items: '.$purchased);

exit 0;

###############################################################################

sub feedback() {
	my ($msg) =  @_;
	my $num_of_spaces = ($indent*$INDENT_MULTIPLIER);
	print(' 'x$num_of_spaces);
	print("$msg\n");
	return 1;
}

sub bomb() {
	my ($msg) =  @_;
	print STDERR "$msg\n";
	exit 1;
}
