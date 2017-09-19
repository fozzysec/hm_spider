#!/usr/bin/env perl
use JSON;
use utf8;
use DBI;
use File::Basename;
use Cwd qw/abs_path/;

binmode(STDOUT, ':encoding(utf8)');
binmode(STDIN, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');

my $path = dirname(abs_path(__FILE__)).'/';
my $script_name = 'hm_no_images.py';
my $filename = 'records.txt';
my $host = 'myhost';
my $user = 'myuser';
my $password = 'mypassword';
my $dbname = 'mydb';

=pod
SQL to create table schema on pgsql:
CREATE TABLE records(id integer PRIMARY KEY, data json NOT NULL);
=cut

my $increment = 1000;

my $conn = DBI->connect("dbi:Pg:dbname=$dbname;host=$host", $user, $password) or die $!;
my $fetch_id = $conn->prepare(qq/SELECT id FROM records order by id desc limit 1/);
$fetch_id->execute;
my @results = $fetch_id->fetchrow_array;
$fetch_id->finish;
my $lastid = int($results[0]);
my $endid;
do{
	$lastid++;
	$endid = $lastid + $increment;
	system($path.$script_name." $lastid $endid $path$filename");
	open(FH, '<:encoding(utf8)', $path.$filename) or die $!;
	while(<FH>){
		my $json_obj = JSON->new->utf8->decode($_);
		my $id = $json_obj->{'id'};
		if($id){
			my $trans = $conn->prepare(qq/INSERT INTO records(id, data) VALUES (?, ?) ON CONFLICT (id) DO NOTHING/);
			$trans->execute($id, $_);
			print("$id $json_obj->{'author'}\t$json_obj->{'content'}\n");
			$trans->finish;
			$lastid = $lastid > $id ? $lastid : $id;
		}
	}
	close(FH);

}while($endid - $lastid < 50);
print("end id: $endid, last id: $lastid\n");
$conn->disconnect;
