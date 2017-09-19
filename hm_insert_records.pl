#!/usr/bin/env perl
use JSON;
use utf8;
use DBI;

binmode(STDOUT, ':encoding(utf8)');
binmode(STDIN, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

my $filename = $ARGV[0];
my $host = $ARGV[1];
my $user = $ARGV[2];
my $password = $ARGV[3];
my $dbname = $ARGV[4];

my $conn = DBI->connect("dbi:Pg:dbname=$dbname;host=$host", $user, $password) or die $!;
open(FH, '<:encoding(utf8)', $filename) or die $!;
while(<FH>){
	my $json_obj = JSON->new->utf8->decode($_);
	my $id = $json_obj->{'id'};
	if($id){
		my $trans = $conn->prepare(qq/INSERT INTO records(id, data) VALUES (?, ?) ON CONFLICT (id) DO NOTHING/);
		$trans->execute($id, $_);
		print("$id $json_obj->{'author'}\t$json_obj->{'content'}\n");
	}
}
close(FH);
$conn->disconnect;
