#!perl

use strict;
use warnings;
$|=1;


# NOTE about t/56writes.t & t/expected.zip...
#
# If the write tests fail, due to any change a new expected.zip file is
# required. In order to regenerate the archive enter the following
# commands:
#
# $> prove -Ilib t/05setup_db-*
# $> perl -Ilib t/56writes.t --update-archive
#
# This will assume that any failing tests are actually correct, and
# create a new zip file t/expected-NEW.zip. To commit it, just enter:
#
# $> mv t/expected-NEW.zip t/expected.zip
#

my $UPDATE_ARCHIVE = ($ARGV[0] && $ARGV[0] eq '--update-archive') ? 1 : 0;


use Test::More tests => 116;
use Test::Differences;
use File::Slurp qw( slurp );
use Archive::Zip;
use Archive::Extract;
use File::Spec;
use File::Path;
use File::Copy;
use File::Basename;

use lib 't';
use CTWS_Testing;

ok( my $obj = CTWS_Testing::getObj(), "got object" );
my $rc;
my @files;
my @expectedFiles;
my $expectedDir;

my $EXPECTEDPATH = File::Spec->catfile( 't', '_EXPECTED' );
my $zip = File::Spec->catfile('t','expected.zip');
if(-f $zip) {
    my $ae = Archive::Extract->new( archive => $zip );
    ok( $ae->extract(to => $EXPECTEDPATH), 'extracted expected files' );
} else {
    ok(0);
}
#---------------------------------------
# Tests for creating pages

my $page = CTWS_Testing::getPages();
my $dir  = $obj->directory();


$page->_write_basics();
check_dir_contents(
	"[_write_basics]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_basics'),
);
ok( CTWS_Testing::cleanDir($obj), 'directory cleaned' );


$page->_report_matrix();
check_dir_contents(
	"[_report_matrix]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._report_matrix'),
);
ok( CTWS_Testing::cleanDir($obj), 'directory cleaned' );


$page->_report_interesting();
check_dir_contents(
	"[_report_interesting]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._report_interesting'),
);
ok( CTWS_Testing::cleanDir($obj), 'directory cleaned' );


$obj->directory($dir . '/_write_stats'),
$page->_write_stats();
check_dir_contents(
	"[_write_stats]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes._write_stats'),
);
ok( CTWS_Testing::cleanDir($obj), 'directory cleaned' );


$obj->directory($dir . '/create'),
$page->create();
check_dir_contents(
	"[create]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes.create'),
);
ok( CTWS_Testing::cleanDir($obj), 'directory cleaned' );


#---------------------------------------
# Tests for creating graphs

my $graph = CTWS_Testing::getGraphs();

$obj->directory($dir . '/graphs'),
$graph->create();
check_dir_contents(
	"[graphs]",
	$obj->directory,
	File::Spec->catfile($EXPECTEDPATH,'56writes.graphs'),
);
ok( CTWS_Testing::cleanDir($obj), 'directory cleaned' );

#---------------------------------------
# Update Code

if( $UPDATE_ARCHIVE ){
  my $zip = Archive::Zip->new();
  $zip->addTree( $EXPECTEDPATH );
  my $f = File::Spec->catfile( 't', 'expected-NEW.zip' );
  diag "CREATING NEW ZIP FILE: $f";
  unlink $f if -f $f;
  $zip->writeToFileNamed($f) == Archive::Zip::AZ_OK
	or diag "==== ERROR WRITING TO $f ====";
}

##################################################################

ok( CTWS_Testing::whackDir($obj), 'directory removed' );
ok( rmtree($EXPECTEDPATH), 'expected dir removed' );

exit;

##################################################################

sub eq_or_diff_files {
  my ($f1, $f2, $desc, $filter) = @_;
  my $s1 = -f $f1 ? slurp($f1) : undef;
  &$filter($s1) if $filter;
  my $s2 = -f $f2 ? slurp($f2) : undef;
  &$filter($s2) if $filter;
  return
	( defined($s1) && defined($s2) )
	? eq_or_diff( $s1, $s2, $desc )
	: ok( 0, "$desc - both files exist")
  ;
}

sub check_dir_contents {
  my ($diz, $dir, $expectedDir) = @_;
  my @files = CTWS_Testing::listFiles( $dir );
  my @expectedFiles = CTWS_Testing::listFiles( $expectedDir );
  ok( scalar(@files), "got files" );
  ok( scalar(@expectedFiles), "got expectedFiles" );
  eq_or_diff( \@files, \@expectedFiles, "$diz file listings match" );
  foreach my $f ( @files ){
    my $fGot = File::Spec->catfile($dir,$f);
    my $fExpected = File::Spec->catfile($expectedDir, $f);
    my $ok = eq_or_diff_files(
	$fGot,
	$fExpected,
	"$diz diff $f",
	sub {
	  $_[0] =~ s/^(\s*)\d+\.\d+(?:_\d+)? at \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.( Comments and design patches)/$1 ==TIMESTAMP== $2/gmi;
	  $_[0] =~ s/\d+(st|nd|rd|th)\s+\w+\s+\d+/==TIMESTAMP==/gmi;
	  $_[0] =~ s!\d{4}/\d{2}/\d{2}!==TIMESTAMP==!gmi;
	}
    );
    next if $ok;
    next unless $UPDATE_ARCHIVE;
    mkpath( dirname($fExpected) ) unless -f $fExpected;
    copy( $fGot, $fExpected );
  }
}