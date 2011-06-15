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
my $abs_path	= './';				# Absolute path to music for output
my $dest		= './';				# Destination for files we generate
my $verbose;						# Be a chatterbox?
my $fname = 'iTunes Library.xml';	# Filename of the iTunes Library
GetOptions (
    "library|L=s"	=> \$fname,		# string
    "dest|d=s"		=> \$dest,		# string
    "abspath|A=s"	=> \$abs_path,	# string
	"verbose|v"		=> \$verbose,	# flag
) or exit 1;

# sanitize the input
$dest		=~ s|/*\z||g;	# strip any trailing slashes
$abs_path	=~ s|/*\z||g;	# strip any trailing slashes

# is everything ok?
&bomb('Path not found: '.$dest)		unless (-d $dest);
&bomb('Path not found: '.$abs_path)	unless (-d $abs_path);
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

&feedback(0, sprintf($FMT, 'Number of Items',	$library->num));
&feedback(0, sprintf($FMT, 'Music Folder',		$library->musicFolder));
&feedback(0, sprintf($FMT, 'Persistent ID',		$library->libraryPersistentID));
&feedback(0, sprintf($FMT, 'Total Size',		format_bytes($library->size)));

# we need this to search and replace it in the song path
my $library_path = $library->musicFolder;

# Loop through each playlist in the library
my $audio_files	= 0;
my $purchased	= 0;
my %playlists = $library->playlists();
print '' if $verbose;
my $playlist_count = scalar keys %playlists;
&feedback(1, sprintf('Found %u playlists to process', $playlist_count));
$indent++;
while (my ($id, $playlist) = each %playlists) {
	# Built-in playlists needs to be skipped
	next if ($playlist->name eq 'Music');
	next if ($playlist->name eq 'Library');
	next if ($playlist->name eq 'TV Shows');
	next if ($playlist->name eq 'Movies');

	# open our output file
	my $oname = sprintf('%s/%s.m3u', $dest, $playlist->name);
	open (PLFILE, ">$oname");

	&feedback(0, sprintf($FMT, 'Playlist Name',	$playlist->name));
	&feedback(0, sprintf($FMT, 'Playlist ID',	$playlist->playlistID));
	&feedback(0, sprintf($FMT, 'Item Count',	$playlist->num));
	&feedback(0, 'Output file is: '.$oname);

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

		&feedback(0, sprintf('%s - %s', $artist, $title));
		&feedback(0, '  ===> '.$song_path);
		print PLFILE "$song_path\n";
	}
	$indent--;
	close (PLFILE); 
}
$indent--;

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

boxcutter [-A I<absolute path to music>] [-d I<destination of output>] [-L I<filename of library>]

=head1 DESCRIPTION

Apple made a total mess of their "XML" format in their iTunes database. This
script utilizes the Mac::iTunes::Library module to extract this information
into formats more useful to applications other that iTunes.

The original goal of the script was to extract my iTunes playlists into m3u
format so I could use the same playlists on my iPhone/iPod and in mpd.

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
