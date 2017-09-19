#!/usr/bin/env perl
use CGI;
use utf8;
use DBI;
use Encode;
use File::Basename;

my $host = qq/myhost/;
my $user = qq/myuser/;
my $password = qq/mypassword/;
my $dbname = qq/mydb/;
my $cgi = CGI->new;
print $cgi->header(-charset => 'utf-8');
my $keyword = $cgi->param('keyword');
my $type = $cgi->param('type');
#my $keyword = $ARGV[0];
#my $type = $ARGV[1];
my $filename = basename($0);
my $form=<<HTML;
<form action="$filename" method="post">
type:
<select name="type">
<option value="content">内容</option>
<option value="author">作者</option>
</select><br>
Keyword:<input type="text" name="keyword"><br>
<input type="submit" value="submit">
<form>
HTML
if(!(defined $keyword && defined $type)){
	print $form;
	die;
}
$keyword = decode('utf8', $keyword);
$type = decode('utf8', $type);
print $form;
print "$type: $keyword<br>\n";
my $conn = DBI->connect("dbi:Pg:dbname=$dbname;host=$host", $user, $password) or die "Can not connect to database";
my $trans;
if($type eq qq/author/){
	$trans = $conn->prepare(qq/SELECT id, data->>'author', data->>'content', data->'images'->>0 FROM records WHERE data->>'author' like ? ORDER BY id ASC/);
}
elsif($type eq qq/content/){
	$trans = $conn->prepare(qq/SELECT id, data->>'author', data->>'content', data->'images'->>0 FROM records WHERE data->>'content' like ? ORDER BY id ASC/);
}
else{
	print "undefined type, abort";
	die;
}
$trans->execute('%'.$keyword.'%');
if($trans->rows > 10000){
	print "<p>Too many records found, abort.</P>";
	die;
}
print "<table border='1'>\n";
print "<th>id</th><th>作者</th><th>内容</th><th>图片</th>\n";

while(my @row = $trans->fetchrow_array){
	print "<tr>";
	print "<td><a href='https://haimanchajian.com/jx3/secret/posts/$row[0]'>$row[0]</a></td><td>$row[1]</td><td>$row[2]</td><td><a href='$row[3]'>$row[3]</a></td>\n";
	print "</tr>";
}
print "</table>";
$trans->finish;
$conn->disconnect;
