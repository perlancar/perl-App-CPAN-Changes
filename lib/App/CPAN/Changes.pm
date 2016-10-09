package App::CPAN::Changes;

# DATE
# VERSION

#use 5.010001;
use strict;
use warnings;

use Fcntl qw(:DEFAULT);

our %SPEC;

sub _parse {
    my ($file) = @_;

    if (!$file) {
	for (qw/Changes CHANGES ChangeLog CHANGELOG/) {
	    do { $file = $_; last } if -f $_;
	}
    }
    return [400, "Please specify file ".
                "(or run in directory where Changes file exists)"]
        unless $file;

    require CPAN::Changes;
    ($file, CPAN::Changes->load($file));
}

my %common_args = (
    file => {
        schema => 'str*', # XXX filename
        summary => 'If not specified, will look for file called '.
            'Changes/CHANGELOG/etc in current directory',
        cmdline_aliases => {f=>{}},
    },
);

$SPEC{check} = {
    v => 1.1,
    summary => 'Check for parsing errors in Changes file',
    args => {
        %common_args,
    },
};
sub check {
    my %args = @_;

    my ($file, $ch) = _parse($args{file});
    my @rels = $ch->releases;
    return [400, "No releases found"] unless @rels;

    [200, "OK"];
}

$SPEC{dump} = {
    v => 1.1,
    summary => 'Dump Changes as JSON structure',
    args => {
        %common_args,
    },
};
sub dump {
    my %args = @_;

    my ($file, $ch) = _parse($args{file});

    require Data::Clean::JSON;
    [200, "OK", Data::Clean::JSON->get_cleanser->clone_and_clean($ch)];
}

sub _write {
    my ($file, $ch, $reverse) = @_;

    my $tempfile = sprintf("%s.%05d.tmp", $file, rand()*65536);
    sysopen my($fh), $tempfile, O_WRONLY|O_CREAT|O_EXCL
        or die "Can't open temp file '$tempfile': $!";
    print $fh $ch->serialize(reverse => $reverse);
    rename $tempfile, $file
        or die "Can't replace '$file': $!";
}

$SPEC{preamble} = {
    v => 1.1,
    summary => 'Get/set preamble',
    args => {
        %common_args,
        preamble => {
            summary => 'Set new preamble',
            schema => 'str*',
            pos => 0,
        },
    },
};
sub preamble {
    my %args = @_;

    my ($file, $ch) = _parse($args{file});

    if (defined $args{preamble}) {
        $ch->preamble($args{preamble});
        _write($file, $ch);
        [200, "OK"];
    } else {
        [200, "OK", $ch->preamble];
    }
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See included script L<cpan-changes>.


=head1 SEE ALSO

L<CPAN::Changes>

L<parse-cpan-changes> (from L<App::ParseCPANChanges>)

=cut
