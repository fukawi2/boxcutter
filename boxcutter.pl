#!/usr/bin/perl

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

use 5.010_001; # Need Perl version 5.10 for Coalesce operator (//)
use Getopt::Long;
Getopt::Long::Configure ("bundling");
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

# Command line arguments?
my $base_path	= './';				# Base path to music for output
my $dest		= './';				# Destination for files we generate
my $prefix		= 'iTunes';			# Prefix to prepend to playlist names
my $verbose;						# Be a chatterbox?
my ($mk_artist,$mk_genre,$mk_album);# Generate playlist for top X types of songs
my $fname = 'iTunes Library.xml';	# Filename of the iTunes Library
GetOptions (
    "library|L=s"	=> \$fname,		# string
    "dest|d=s"		=> \$dest,		# string
    "base|b=s"		=> \$base_path,	# string
    "prefix|p=s"	=> \$prefix,	# string
    "artist|a=i"	=> \$mk_artist,	# integer
    "genre|g=i"		=> \$mk_genre,	# integer
    "album|A=i"		=> \$mk_album,	# integer
	"verbose|v"		=> \$verbose,	# flag
) or exit 1;

# sanitize the input
$dest		=~ s|/*\z||g;	# strip any trailing slashes
$base_path	=~ s|/*\z||g;	# strip any trailing slashes
# yes, the next 2 lines are weird, but it's not convoluted. basically we just
# make sure that the prefix has a hyphen appended if it's not already there.
$prefix		=~ s|-*\z||g;	# strip any trailing hyphen
$prefix 	.= '-' if (length($prefix));	# append a hyphen

# is everything ok?
&bomb('Path not found: '.$dest)		unless (-d $dest);
&bomb('Path not found: '.$base_path)	unless (-d $base_path);
&bomb('File not found: '.$fname)	unless (-e $fname);

&feedback(1, sprintf('Reading libary file [%s]', $fname));
&feedback(1, 'This could take a while because Apple does not understand XML');
&feedback(1, 'Please be patient, they fucked this up...');
my $library = Mac::iTunes::Library::XML->parse($fname);

print '' if $verbose;
&feedback(1, sprintf('Read library ID [%s] (Version %u.%u from iTunes %s)',
		$library->libraryPersistentID,
		$library->majorVersion,
		$library->minorVersion,
		$library->applicationVersion,
	));

# Give some extra feedback if in verbose mode. The &feedback sub tests for
# verbosity, but test it once here instead of 4 times after we call the sub.
if ($verbose) {
	&feedback(0, sprintf($FMT, 'Number of Items',	$library->num));
	&feedback(0, sprintf($FMT, 'Music Folder',		$library->musicFolder));
	&feedback(0, sprintf($FMT, 'Persistent ID',		$library->libraryPersistentID));
	&feedback(0, sprintf($FMT, 'Total Size',		format_bytes($library->size)));
}

# we need this to search and replace it in the song path
my $library_path = $library->musicFolder;

### TESTING ONLY
#goto MkArtistPlaylists;

my $purchased		= 0;
my %playlists		= $library->playlists();
my $playlist_count	= scalar keys %playlists;
print '' if $verbose;
&feedback(1, sprintf('Found %u playlists to process', $playlist_count));

# Loop through each playlist in the library
$indent++;
Playlist:
while (my ($id, $playlist) = each %playlists) {
	# Built-in playlists needs to be skipped
	if ($playlist->name =~ m/\A(Music|Library|TV Shows|Movies)\z/) {
		&feedback(0, "Skipping $playlist->name");
		next Playlist;
	}

	# open our output file
	my $tmp_fname = sprintf('%s/.%s%s.new', $dest, $prefix, $playlist->name);
	my $out_fname = sprintf('%s/%s%s.m3u', $dest, $prefix, $playlist->name);
	open (TF, ">$tmp_fname");

	# more verbosity feedback
	if ($verbose) {
		&feedback(0, sprintf($FMT, 'Playlist Name',	$playlist->name));
		&feedback(0, sprintf($FMT, 'Playlist ID',	$playlist->playlistID));
		&feedback(0, sprintf($FMT, 'Item Count',	$playlist->num));
		&feedback(0, 'Output file is: '.$out_fname);
	}

	my @pl_items = $playlist->items();
	$indent++;
	Track:
	foreach my $song (@pl_items) {
		# We don't want to include video files
		if ($song->kind =~ m/\b(video|movie)\b/i) {
			next Track;
		}

		# Using the coalesce operator (//) we are able to select the first defined
		# value that is appropiate for the field (or the default empty string)
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
		$purchased++ if ($song->kind =~ m/\bpurchased\b/i);

		if ($verbose) {
			&feedback(0, sprintf('%s - %s', $artist, $title));
			&feedback(0, '  ===> '.$song_path);
		}

		print TF sprintf("%s/%s\n", $base_path, $song_path);
	}
	$indent--;

	close (TF);
	rename($tmp_fname, $out_fname);
}
$indent--;
&feedback(0, 'Total number of purchased items: '.$purchased);

&feedback(1, 'Total number of items in playlists: '.$audio_files);
&feedback(1, 'Total number of purchased items: '.$purchased);

exit 0;

###############################################################################
### SUBROUTINES
###############################################################################

sub feedback() {
	my ($ignore_verbose, $msg) =  @_;
	my $num_of_spaces = ($indent*$INDENT_MULTIPLIER);

	return unless ($verbose or $ignore_verbose);

	print(' 'x$num_of_spaces);
	print("$msg\n");

	return 1;
}

sub bomb() {
	my ($msg) =  @_;
	print STDERR "$msg\n";
	exit 1;
}

__END__

###############################################################################
### POD DOCUMENTATION MARKUP
###############################################################################

=head1 NAME

boxcutter - Extract information from your iTunes Library.

=head1 SYNOPSIS

boxcutter [OPTIONS]

Without any extra options, attempt to open F<iTunes Library.xml> in the current
directory and write out a playlist (one file per playlist) in m3u format to the
current directory for each playlist found in the iTunes library file, subject
to L<CAVEATS> below.

=head1 DESCRIPTION

Apple made a total mess of their "XML" format in their iTunes database. This
script utilizes the Mac::iTunes::Library module to extract this information
into formats more useful to applications other that iTunes.

The original goal of the script was to extract my iTunes playlists into m3u
format so I could use the same playlists on my iPhone/iPod and in mpd.

=head1 OPTIONS

=over 4

=item -a, --artist I<num>

Generate a playlist for each artist in the library. Limit to top "num" artists
sorted by their play count. Set "num" to 0 to get playlists for ALL artists.

=item -A, --album I<num>

Generate a playlist for each album in the library. Limit to top "num" albums
sorted by their play count. Set "num" to 0 to get playlists for ALL albums.

=item -b, --base I<(base path to music)>

A path to prepend to the relative path to songs before writing them into the
generated playlist(s).
Default: I<none>

=item -d, --dest I<(destination of output)>

Path (absolute or relative) to save the generated playlist(s).
Default: C<pwd>

=item -g, --genre I<num>

Generate a playlist for each genre in the library. Limit to top "num" genres
sorted by their play count. Set "num" to 0 to get playlists for ALL genres.

=item -L, --library I<(filename of library)>

Full path and filename (absolute or relative) of the iTune Library XML file.
Default: F<iTunes Library.xml>

=item -p, --prefix I<prefix>

A string to prefix to the name of generated playlists.
Default: iTunes

=item -v, --verbose

Be really noisy on the feedback given on stdout. Basic information and errors
will still be displayed WITHOUT this flag. Generally only useful for debugging
or if you like reading every song in your library :P

=back

=head1 LIBRARY DUPLICATION

As the original task of this script was to make my iTunes playlists useable on
my Linux desktop, I needed to regularly sync my iTune Library from my Mac to my
desktop. This command may be useful to others if you are trying to do something
similar. It uses rsync over SSH to synchronize and is very efficient after the
initial sync is done.

 rsync -av --delete --chmod=u=rwX,go=rX --delete-excluded --prune-empty-dirs \
	   --exclude=*.mp4 --exclude=*.m4v --exclude=*.ipa --exclude=*.plist \
	   --exclude=Album\ Artwork --exclude=*.app --exclude=Mobile\ Applications \
	   192.168.1.1:Music/iTunes/* /mnt/music/

192.168.1.1 is the IP Address of the Mac. You can use hostname instead.

=head1 CAVEATS

=over 4

=item * Movie and Video files are exlicitly skipped.

=item * iTunes includes several in-built playlists that are explicitly skipped:

=over 4

=item * "Library" (ALL items in the library)

=item * "Music" (ALL music in the library)

=item * "TV Shows" (ALL TV Shows in the library)

=item * "Movies" (ALL movies in the library)

=back

=back

=head1 BUGS

=head2 Reporting Bugs

Email bug reports to <fukawi2@gmail.com>

=head2 Known Bugs

None ;-)

=head1 ACKNOWLEDGEMENTS

Thanks to Drew Stephens for the Mac::iTunes::Library module. I nearly screamed
after seeing Apple's "XML" and before seeing Drew's module.

=head1 LICENSE

Copyright 2011 Phillip Smith

Made available under the conditions of the GPLv3. This is free software; refer
to the COPYING file for details.

There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 AVAILABILITY

<http://github.com/fukawi2/boxcutter/>

=head1 AUTHOR

Phillip Smith aka fukawi2

=head1 SEE ALSO

<http://search.cpan.org/dist/Mac-iTunes-Library/>

=cut
