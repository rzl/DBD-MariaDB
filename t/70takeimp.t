use strict;
use warnings;

use Test::More;
use DBI;
use lib 't', '.';
require 'lib.pl';
$|= 1;
use vars qw($test_dsn $test_user $test_password);

my $drh = eval { DBI->install_driver('MariaDB') } or do {
    plan skip_all => "Can't obtain driver handle ERROR: $@. Can't continue test";
};

my $dbh = DbiTestConnect($test_dsn, $test_user, $test_password,
                      { RaiseError => 1, PrintError => 1, AutoCommit => 0 });

plan tests => 31;

pass("obtained driver handle");
pass("connected to database");

my $id= connection_id($dbh);
ok defined($id), "Initial connection: $id\n";

$drh = $dbh->{Driver};
ok $drh, "Driver handle defined\n";

my $imp_data;
$imp_data = $dbh->take_imp_data;

ok $imp_data, "Didn't get imp_data";

my $imp_data_length= length($imp_data);
cmp_ok $imp_data_length, '>=', 80,
    "test that our imp_data is greater than or equal to 80, actual $imp_data_length";

is $drh->{Kids}, 0,
    'our Driver should have 0 Kid(s) after calling take_imp_data';

{
    my $warn;
    local $SIG{__WARN__} = sub { ++$warn if $_[0] =~ /after take_imp_data/ };

    my $drh = $dbh->{Driver};
    ok !defined($drh), '... our Driver should be undefined';

    my $trace_level = $dbh->{TraceLevel};
    ok !defined($trace_level) ,'our TraceLevel should be undefined';

    ok !defined($dbh->disconnect), 'disconnect should return undef';

    ok !defined($dbh->quote(42)), 'quote should return undefined';

    is $warn, 4, 'we should have received 4 warnings';
}

my $dbh2 = DBI->connect($test_dsn, $test_user, $test_password,
    { dbi_imp_data => $imp_data });

# XXX: how can we test that the same connection is used?
my $id2 = connection_id($dbh2);
note "Overridden connection: $id2\n";

cmp_ok $id,'==', $id2, "the same connection: $id => $id2\n";

my $drh2;
ok $drh2 = $dbh2->{Driver}, "can't get the driver\n";

ok $dbh2->isa("DBI::db"), 'isa test';
# need a way to test dbi_imp_data has been used

is $drh2->{Kids}, 1,
    "our Driver should have 1 Kid(s) again: having " .  $drh2->{Kids} . "\n";

is $drh2->{ActiveKids}, 1,
    "our Driver should have 1 ActiveKid again: having " .  $drh2->{ActiveKids} . "\n";

read_write_test($dbh2);

# this will cut the connection data, at the end connection should be properly closed
ok ($imp_data = $dbh2->take_imp_data, "didn't get imp_data");

# install a handler so that a warning about unfreed resources gets caught
$SIG{__WARN__} = sub { die @_ };

ok my $dbh3 = DBI->connect($test_dsn, $test_user, $test_password);

read_write_test($dbh3);

ok my $imp_data2 = $dbh3->take_imp_data;

ok my $dbh4 = DBI->connect($test_dsn, $test_user, $test_password, { dbi_imp_data => $imp_data });

ok ! defined eval { DBI->connect($test_dsn, $test_user, $test_password, { dbi_imp_data => $imp_data }) }, 'reusing same imp_data for two different connections is not possible';

read_write_test($dbh4);

sub read_write_test {
    my ($dbh)= @_;

    # now the actual test:

    ok $dbh->do("DROP TABLE IF EXISTS dbd_mysql_t70takeimp");

    my $create= <<EOT;
CREATE TABLE dbd_mysql_t70takeimp (
        id int(4) NOT NULL default 0,
        name varchar(64) NOT NULL default '' );
EOT

    ok $dbh->do($create);

    ok $dbh->do("DROP TABLE dbd_mysql_t70takeimp");
}

